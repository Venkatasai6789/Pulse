import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/soil.dart';
import '../data/local_db.dart';
import '../models/models.dart';

/// Supported 2026 Gemini Free-Tier working models in priority order for fallback.
const List<String> kAiModels = [
  'gemini-3.8-flash',
  'gemini-3.6-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-3-flash',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
];

/// 20-second timeout for model requests.
const Duration kAiTimeout = Duration(seconds: 20);

/// Friendly fallback message shown to users on any general error path.
const String kAiFallbackMessage =
    'AI insights are currently unavailable. Please try again later.';

/// System instruction for expert pollinator advisory analysis.
const String kAiSystemInstruction = '''
You are an expert pollinator ecologist and environmental scientist for the P.U.L.S.E. (Pollinator Unified Landscape and Sustainability Ecosystem) initiative.
Analyze pollinator observation data, environmental indicators, habitat quality, and field photos.
Provide constructive, science-backed ecological insights, photo findings, and actionable habitat improvement suggestions.
Your output must strictly adhere to the requested JSON schema.
If a soil moisture reading is provided, write soilAdvice: one or two plain sentences that connect the reading to what is visible in the photos (bare ground for ground-nesting bees, wilting or lush flowers, standing water, mulch) and give one practical action. If no reading is provided, return an empty string for soilAdvice. Never suggest a change to the PHI score.
''';

/// Response schema for structured JSON output parsed into [AiInsight] (Firebase AI schema).
final Schema kAiInsightSchema = Schema.object(
  properties: {
    'isHabitatPhoto': Schema.boolean(
      description: 'True if the photo contains outdoor flora, garden, vegetation, or pollinator habitat. False if it depicts a person, portrait, selfie, indoor room, vehicle, or other non-habitat subject.',
    ),
    'summary': Schema.string(
      description: 'A concise 1-2 sentence ecological summary of the habitat observations and pollinator health.',
    ),
    'photoFindings': Schema.array(
      items: Schema.string(),
      description: 'Specific ecological observations from the provided photos.',
    ),
    'suggestions': Schema.array(
      items: Schema.string(),
      description: 'Actionable tips for habitat enhancement (maximum 2).',
    ),
    'habitatSuggestions': Schema.array(
      items: Schema.object(
        properties: {
          'field': Schema.string(description: 'Habitat field name: flowers, nesting, shelter, or water'),
          'value': Schema.string(description: 'Suggested level: High, Medium, Low (or Present, Absent for water)'),
          'confidence': Schema.number(description: 'Confidence score between 0.0 and 1.0'),
        },
      ),
      description: 'Suggested habitat parameter levels based on visual photo analysis. Empty if not a habitat photo.',
    ),
    'soilAdvice': Schema.string(
      description: 'One or two plain sentences connecting soil moisture reading to visible photo elements with one practical action, or empty string if no reading.',
    ),
  },
  optionalProperties: ['isHabitatPhoto', 'photoFindings', 'suggestions', 'habitatSuggestions', 'soilAdvice'],
);

/// REST Schema for direct Gemini Developer API calls.
const Map<String, dynamic> kAiInsightRestSchema = {
  'type': 'OBJECT',
  'properties': {
    'isHabitatPhoto': {
      'type': 'BOOLEAN',
      'description': 'True if the photo contains outdoor flora, garden, vegetation, or pollinator habitat. False if it depicts a person, portrait, selfie, indoor room, or other non-habitat subject.',
    },
    'summary': {
      'type': 'STRING',
      'description': 'A concise 1-2 sentence ecological summary of the habitat observations and pollinator health.',
    },
    'photoFindings': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'},
      'description': 'Specific ecological observations from the provided photos.',
    },
    'suggestions': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'},
      'description': 'Actionable tips for habitat enhancement (maximum 2).',
    },
    'soilAdvice': {
      'type': 'STRING',
      'description': 'One or two plain sentences connecting soil moisture reading to visible photo elements with one practical action, or empty string if no reading.',
    },
    'habitatSuggestions': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'field': {'type': 'STRING', 'description': 'Habitat field name: flowers, nesting, shelter, or water'},
          'value': {'type': 'STRING', 'description': 'Suggested level: High, Medium, Low (or Present, Absent for water)'},
          'confidence': {'type': 'NUMBER', 'description': 'Confidence score between 0.0 and 1.0'},
        },
        'required': ['field', 'value', 'confidence'],
      },
      'description': 'Suggested habitat parameter levels based on visual photo analysis. Leave empty if isHabitatPhoto is false.',
    },
  },
  'required': ['summary'],
};

class AiException implements Exception {
  final String message;
  const AiException([this.message = kAiFallbackMessage]);

  @override
  String toString() => message;
}

/// Computes the Pacific Time offset (in hours relative to UTC) considering Daylight Saving Time.
int getPacificOffsetHours(DateTime utc) {
  final year = utc.year;
  DateTime marchSunday = DateTime.utc(year, 3, 8);
  while (marchSunday.weekday != DateTime.sunday) {
    marchSunday = marchSunday.add(const Duration(days: 1));
  }
  final dstStart = DateTime.utc(year, 3, marchSunday.day, 10);

  DateTime novSunday = DateTime.utc(year, 11, 1);
  while (novSunday.weekday != DateTime.sunday) {
    novSunday = novSunday.add(const Duration(days: 1));
  }
  final dstEnd = DateTime.utc(year, 11, novSunday.day, 9);

  final isDst = utc.isAfter(dstStart) && utc.isBefore(dstEnd);
  return isDst ? -7 : -8;
}

/// Returns the DateTime (in UTC) corresponding to the upcoming midnight in Pacific Time.
DateTime getNextMidnightPacific(DateTime now) {
  final nowUtc = now.toUtc();
  final offsetHours = getPacificOffsetHours(nowUtc);
  final pacificTime = nowUtc.add(Duration(hours: offsetHours));
  final pacificTomorrow = DateTime.utc(pacificTime.year, pacificTime.month, pacificTime.day + 1);
  return pacificTomorrow.subtract(Duration(hours: offsetHours));
}

/// Checks whether an error is due to rate limiting or resource exhaustion.
bool isExhaustionError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('429') ||
      msg.contains('resource_exhausted') ||
      msg.contains('quota') ||
      msg.contains('503');
}

typedef ModelRunner = Future<String> Function({
  required String modelName,
  required Content content,
  required Schema schema,
});

class AiService {
  AiService({this.firebaseAI, http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  final FirebaseAI? firebaseAI;
  final http.Client httpClient;

  static AiService instance = AiService();

  static const String _kExhaustedPrefix = 'pulse_ai_exhausted_';

  /// Optional runner hook used during unit tests to avoid live network calls.
  @visibleForTesting
  ModelRunner? testModelRunner;

  FirebaseAI get _ai => firebaseAI ?? FirebaseAI.googleAI();

  /// Checks if [model] has been recorded as exhausted and whether it is still before midnight Pacific.
  Future<bool> isModelExhausted(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiry = prefs.getInt('$_kExhaustedPrefix$model');
      if (expiry == null) return false;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiry) {
        await prefs.remove('$_kExhaustedPrefix$model');
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remembers that [model] is exhausted until midnight Pacific in SharedPreferences.
  Future<void> markModelExhausted(String model, {DateTime? customExpiry}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiry = customExpiry ?? getNextMidnightPacific(DateTime.now());
      await prefs.setInt('$_kExhaustedPrefix$model', expiry.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Clears recorded exhausted models in SharedPreferences.
  Future<void> clearExhaustedModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final model in kAiModels) {
        await prefs.remove('$_kExhaustedPrefix$model');
      }
    } catch (_) {}
  }

  Map<String, dynamic> _contentToJson(Content content) {
    final partsList = <Map<String, dynamic>>[];
    for (final part in content.parts) {
      if (part is TextPart) {
        partsList.add({'text': part.text});
      } else if (part is InlineDataPart) {
        partsList.add({
          'inlineData': {
            'mimeType': part.mimeType,
            'data': base64Encode(part.bytes),
          }
        });
      }
    }
    return {
      'role': content.role ?? 'user',
      'parts': partsList,
    };
  }

  /// Calls the Gemini Developer API directly via REST with user-provided API key from SQLite.
  Future<String> _callGeminiRest({
    required String apiKey,
    required String modelName,
    required Content content,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': kAiSystemInstruction}
        ]
      },
      'contents': [_contentToJson(content)],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': kAiInsightRestSchema,
      },
    };

    final response = await httpClient
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(
          kAiTimeout,
          onTimeout: () => throw const AiException('Request timed out. Please try again later.'),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const AiException('No suggestions returned from AI model.');
      }
      final contentMap = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = contentMap?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const AiException('Empty response received from AI model.');
      }
      final text = parts[0]['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw const AiException('Empty text content received from AI.');
      }
      return text;
    } else {
      String errMessage = response.body;
      String errStatus = '';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is Map<String, dynamic>) {
          final errMap = decoded['error'] as Map<String, dynamic>;
          errMessage = errMap['message']?.toString() ?? errMessage;
          errStatus = errMap['status']?.toString() ?? '';
        }
      } catch (_) {}

      final lowerMsg = errMessage.toLowerCase();
      if (response.statusCode == 429 ||
          errStatus == 'RESOURCE_EXHAUSTED' ||
          lowerMsg.contains('quota') ||
          lowerMsg.contains('resource_exhausted') ||
          response.statusCode == 503) {
        throw AiException('RESOURCE_EXHAUSTED: $errMessage');
      }

      if (response.statusCode == 404 || errStatus == 'NOT_FOUND') {
        throw AiException('NOT_FOUND: $errMessage');
      }

      if (response.statusCode == 400 && lowerMsg.contains('api key')) {
        throw const AiException('Invalid Gemini API Key. Please verify your key in Profile & Settings.');
      }

      throw AiException('Gemini API Error (${response.statusCode}): $errMessage');
    }
  }

  /// Invokes FirebaseAI as a secondary option if configured.
  Future<String> _callRealGemini({
    required String modelName,
    required Content content,
    required Schema schema,
  }) async {
    final model = _ai.generativeModel(
      model: modelName,
      systemInstruction: Content.system(kAiSystemInstruction),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
      ),
    );

    final response = await model
        .generateContent([content])
        .timeout(
          kAiTimeout,
          onTimeout: () => throw const AiException('Request timed out. Please try again later.'),
        );

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const AiException('Empty response received from AI model.');
    }
    return text;
  }

  /// Tests whether a given Gemini API key is valid by sending a lightweight test request.
  Future<void> testApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const AiException('Gemini API key cannot be empty.');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${kAiModels.first}:generateContent?key=$trimmed',
    );

    try {
      final response = await httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'Ping'}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return;
      }

      String message = 'Verification failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is Map<String, dynamic>) {
          message = decoded['error']['message']?.toString() ?? message;
        }
      } catch (_) {}
      throw AiException(message);
    } on TimeoutException {
      throw const AiException('Verification timed out. Check your internet connection.');
    }
  }

  /// Executes prompt with model fallback across [kAiModels].
  Future<AiInsight> generateWithFallback({
    required Content content,
    required Schema schema,
  }) async {
    // If unit test hook is set, use it directly
    if (testModelRunner != null) {
      Object? lastError;
      for (final modelName in kAiModels) {
        if (await isModelExhausted(modelName)) {
          continue;
        }
        try {
          final rawJson = await testModelRunner!(
            modelName: modelName,
            content: content,
            schema: schema,
          );
          return parseInsightResponse(rawJson, modelName);
        } catch (e) {
          lastError = e;
          if (isExhaustionError(e)) {
            await markModelExhausted(modelName);
          }
          continue;
        }
      }
      throw AiException(
        lastError is AiException ? lastError.message : kAiFallbackMessage,
      );
    }

    // Retrieve API key stored in local SQLite
    final apiKey = await LocalDb.instance.getGeminiApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      if (firebaseAI == null) {
        throw const AiException(
          'Gemini API key not configured. Please add your key in Profile & Settings to enable AI analysis.',
        );
      }
    }

    Object? lastError;

    for (final modelName in kAiModels) {
      if (await isModelExhausted(modelName)) {
        debugPrint('[AiService] Model $modelName is exhausted until midnight Pacific. Skipping.');
        continue;
      }

      try {
        final rawJson = (apiKey != null && apiKey.isNotEmpty)
            ? await _callGeminiRest(
                apiKey: apiKey,
                modelName: modelName,
                content: content,
              )
            : await _callRealGemini(
                modelName: modelName,
                content: content,
                schema: schema,
              );

        final insight = parseInsightResponse(rawJson, modelName);
        return insight;
      } catch (e) {
        lastError = e;
        debugPrint('[AiService] Error on model $modelName: $e');
        if (isExhaustionError(e)) {
          await markModelExhausted(modelName);
          debugPrint('[AiService] Marked $modelName as exhausted until midnight Pacific.');
          continue;
        }
        // Non-exhaustion error (e.g. 404 model not found, timeout), try next fallback model
        continue;
      }
    }

    // All fallback models failed or were exhausted
    throw AiException(
      lastError is AiException ? lastError.message : kAiFallbackMessage,
    );
  }

  /// Parses JSON response into an [AiInsight] model.
  AiInsight parseInsightResponse(String responseText, String modelName) {
    try {
      var raw = responseText.trim();
      if (raw.startsWith('```json')) {
        raw = raw.substring(7);
      } else if (raw.startsWith('```')) {
        raw = raw.substring(3);
      }
      if (raw.endsWith('```')) {
        raw = raw.substring(0, raw.length - 3);
      }
      raw = raw.trim();

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AiInsight.fromJson({
        ...map,
        'model': modelName,
        'generatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw const AiException('Failed to parse AI insights. Please try again.');
    }
  }

  /// Builds multimodal content with text prompt and base64 encoded photo bytes.
  Future<Content> createMultimodalContent({
    required String promptText,
    List<String> photoPaths = const [],
  }) async {
    final parts = <Part>[TextPart(promptText)];

    for (final path in photoPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final ext = path.split('.').last.toLowerCase();
          final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          parts.add(InlineDataPart(mimeType, bytes));
        }
      } catch (e) {
        debugPrint('[AiService] Failed to read photo at $path: $e');
      }
    }

    return Content.multi(parts);
  }

  /// Generates ecological insights for a completed [Assessment].
  Future<AiInsight> generateAssessmentInsights(Assessment assessment) async {
    final buffer = StringBuffer();
    buffer.writeln('Assess the following pollinator habitat survey:');
    buffer.writeln('Location ID: ${assessment.locationId ?? "Unknown"}');
    buffer.writeln('Visits counted: ${assessment.visits ?? "N/A"}');
    buffer.writeln('Duration: ${assessment.durationMinutes ?? "N/A"} minutes');
    buffer.writeln('Flowers: ${assessment.flowers?.name ?? "N/A"}');
    buffer.writeln('Nesting: ${assessment.nesting?.name ?? "N/A"}');
    buffer.writeln('Shelter: ${assessment.shelter?.name ?? "N/A"}');
    buffer.writeln('Water: ${assessment.water?.name ?? "N/A"}');
    final dhtNote = assessment.climateSource == 'esp32_dht11'
        ? ' (live ESP32 DHT11${assessment.climateDeviceId != null ? " sensor ${assessment.climateDeviceId}" : ""})'
        : '';
    buffer.writeln('Temperature: ${assessment.temperatureC ?? "N/A"}°C$dhtNote');
    buffer.writeln('Humidity: ${assessment.humidityPct ?? "N/A"}%$dhtNote');
    buffer.writeln('CO2: ${assessment.co2Ppm ?? "N/A"} ppm');
    if (assessment.soil != null) {
      final s = assessment.soil!;
      final dateStr = DateFormat('d MMM yyyy HH:mm').format(s.capturedAt);
      buffer.writeln(
        'Soil moisture: ${s.percent.round()} % (status ${s.status.name.toUpperCase()}, band ${soilLabel(s.status)}), source ${s.source.name} sensor,',
      );
      buffer.writeln(
        'captured $dateStr. Optimal band for this app is 40–60 %.',
      );
    }
    buffer.writeln('Computed PHI Score: ${assessment.result?.phi ?? "N/A"}');
    buffer.writeln('Computed Tier: ${assessment.result?.tier.name.toUpperCase() ?? "N/A"}');
    final activeRisks = <String>[];
    if (assessment.riskIndicators.pesticide) activeRisks.add('pesticide');
    if (assessment.riskIndicators.chemical) activeRisks.add('chemical');
    if (assessment.riskIndicators.traffic) activeRisks.add('traffic');
    if (assessment.riskIndicators.other) activeRisks.add('other');
    if (activeRisks.isNotEmpty) {
      buffer.writeln('Risk indicators present: ${activeRisks.join(", ")}');
    }

    final content = await createMultimodalContent(
      promptText: buffer.toString(),
      photoPaths: assessment.activityPhotoPaths,
    );

    return await generateWithFallback(
      content: content,
      schema: kAiInsightSchema,
    );
  }

  /// Analyzes habitat photos from [draft] or [photoPaths] during Monitor step 2.
  Future<AiInsight> analyseHabitatPhotos([
    dynamic photoPathsOrDraft,
    Assessment? draftParam,
  ]) async {
    List<String> paths = [];
    if (photoPathsOrDraft is List<String>) {
      paths = photoPathsOrDraft;
    } else if (photoPathsOrDraft is Assessment) {
      paths = photoPathsOrDraft.activityPhotoPaths;
    } else if (draftParam != null) {
      paths = draftParam.activityPhotoPaths;
    }

    if (paths.isEmpty) {
      throw const AiException('No photos provided for analysis.');
    }

    const promptText = '''
Analyze these field photos carefully.
Step 1: Check image content.
- If the image depicts a human face, portrait, selfie, person, indoor furniture, pet, vehicle, food, or non-outdoor scene:
  * Set "isHabitatPhoto": false
  * Set "summary": "Uploaded photo depicts a person or non-habitat subject rather than outdoor pollinator flora or habitat."
  * Set "photoFindings": ["A person or non-habitat subject was detected.", "No outdoor flowering plants, nesting grounds, or pollinator habitat elements could be evaluated."]
  * Set "habitatSuggestions": [] (do NOT suggest flowers, nesting, shelter, or water values for a person's photo)
  * Set "suggestions": ["Please capture outdoor flower beds, garden patches, or native vegetation for accurate ecological scoring."]

Step 2: If the image DOES depict outdoor flora, plants, or pollinator habitat:
  * Set "isHabitatPhoto": true
  * Examine floral density and diversity, bare soil or nesting cavities, shrubs/tall grass for shelter, and shallow water availability.
  * Provide suggested ratings for:
    - flowers: High, Medium, or Low
    - nesting: High, Medium, or Low
    - shelter: High, Medium, or Low
    - water: Present or Absent
  * Provide a concise 1-sentence ecological summary and 1-2 photo findings.
''';

    final content = await createMultimodalContent(
      promptText: promptText,
      photoPaths: paths,
    );

    return await generateWithFallback(
      content: content,
      schema: kAiInsightSchema,
    );
  }

  /// Queries Google Generative Language API to fetch live list of available models.
  Future<List<Map<String, dynamic>>> fetchAvailableModels({String? apiKey}) async {
    final key = apiKey ?? await LocalDb.instance.getGeminiApiKey();
    if (key == null || key.isEmpty) {
      throw const AiException('Gemini API key is required to query available models.');
    }

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
    final response = await httpClient.get(url).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw const AiException('Timed out fetching available models.'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final modelsList = (data['models'] as List<dynamic>?) ?? [];
      return modelsList
          .map((m) => Map<String, dynamic>.from(m as Map))
          .where((m) {
            final methods = (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
            return methods.contains('generateContent');
          })
          .toList();
    } else {
      String msg = 'Failed to fetch models (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] is Map<String, dynamic>) {
          msg = decoded['error']['message']?.toString() ?? msg;
        }
      } catch (_) {}
      throw AiException(msg);
    }
  }
}
