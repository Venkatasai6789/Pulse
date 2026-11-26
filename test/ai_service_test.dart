import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse/ai/ai_service.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/data/local_db.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/monitor/widgets/step2_habitat.dart';
import 'package:pulse/screens/monitor/widgets/shake_wrapper.dart';
import 'package:pulse/screens/results/results_screen.dart';
import 'package:pulse/theme/app_theme.dart';

class FakeApiService implements ApiService {
  final Map<String, Assessment> assessments = {};
  final Map<String, Location> locations = {};

  @override
  Future<Assessment?> getAssessment(String id) async => assessments[id];

  @override
  Future<Location?> getLocation(String id) async => locations[id];

  @override
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true}) async {
    return assessments.values
        .where((a) => locationId == null || a.locationId == locationId)
        .where((a) => !submittedOnly || a.isSubmitted)
        .toList();
  }

  @override
  Future<Assessment> addActionTaken(String assessmentId, ActionTaken action) async {
    final a = assessments[assessmentId];
    if (a == null) throw Exception('Not found');
    final updated = a.copyWith(actionsTaken: [...a.actionsTaken, action]);
    assessments[assessmentId] = updated;
    return updated;
  }

  @override
  Future<Assessment> updateAssessmentAi(String assessmentId, AiInsight ai) async {
    final a = assessments[assessmentId];
    if (a == null) throw Exception('Not found');
    final updated = a.copyWith(ai: ai);
    assessments[assessmentId] = updated;
    return updated;
  }

  @override
  Future<Assessment> submitAssessment(Assessment draft) async {
    final result = calculatePhi(draft.toInputs());
    final s = draft.copyWith(
      status: AssessmentStatus.submitted,
      result: result,
      submittedAt: DateTime.now(),
    );
    assessments[s.id] = s;
    return s;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AiService.instance = AiService();
  });

  group('Unit Test: Invariance of assessment.result when generating AI insights', () {
    test('Generating AI insights does NOT change assessment.result, PHI or tier', () async {
      // 1. Setup sample inputs and compute reference score
      const inputs = AssessmentInputs(
        visits: 18,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final originalResult = calculatePhi(inputs);
      expect(originalResult.phi, 91);
      expect(originalResult.tier, Tier.protect);

      final assessment = Assessment(
        id: 'test-123',
        locationId: 'loc-1',
        status: AssessmentStatus.submitted,
        visits: 18,
        durationMinutes: 5,
        observedAt: DateTime(2026, 11, 14, 10, 0),
        weather: 'Sunny',
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        riskLevel: RiskLevel.low,
        result: originalResult,
        createdAt: DateTime(2026, 11, 14, 10, 0),
        submittedAt: DateTime(2026, 11, 14, 10, 5),
      );

      // 2. Mock AI runner to return valid insights
      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        return jsonEncode({
          'summary': 'High diversity habitat supporting dense pollinator forage.',
          'photoFindings': ['Native flowering shrubs present', 'Active honeybees observed'],
          'suggestions': [
            'Maintain perennial bloom sequence into late autumn',
            'Add shallow perched water station'
          ],
        });
      };

      // 3. Generate AI insights
      final insight = await AiService.instance.generateAssessmentInsights(assessment);
      expect(insight.summary, 'High diversity habitat supporting dense pollinator forage.');
      expect(insight.suggestions.length, 2);

      // 4. Attach to assessment (as results_screen does via copyWith)
      final assessmentWithAi = assessment.copyWith(ai: insight);

      // 5. Verify that assessment.result is strictly unchanged
      expect(assessmentWithAi.result, isNotNull);
      expect(assessmentWithAi.result, equals(originalResult));
      expect(assessmentWithAi.result!.phi, equals(originalResult.phi));
      expect(assessmentWithAi.result!.tier, equals(originalResult.tier));
      expect(assessmentWithAi.result!.activity, equals(originalResult.activity));
      expect(assessmentWithAi.result!.habitat, equals(originalResult.habitat));
      expect(assessmentWithAi.result!.environmental, equals(originalResult.environmental));
      expect(assessmentWithAi.result!.risk, equals(originalResult.risk));
      expect(assessmentWithAi.result!.version, equals(originalResult.version));

      // Recomputing PHI from inputs must also remain identical
      final recomputed = calculatePhi(assessmentWithAi.toInputs());
      expect(recomputed.phi, equals(originalResult.phi));
      expect(recomputed.tier, equals(originalResult.tier));
    });
  });

  group('Fallback Logic & Model Exhaustion (429 / RESOURCE_EXHAUSTED / quota / 503)', () {
    test('Falls back from exhausted model to next model in kAiModels and remembers until midnight Pacific', () async {
      final calledModels = <String>[];

      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        calledModels.add(modelName);
        if (modelName == kAiModels[0]) {
          // Model 1 fails with 429 quota exhaustion
          throw Exception('RESOURCE_EXHAUSTED: 429 Quota exceeded for model $modelName');
        }
        // Model 2 succeeds
        return jsonEncode({
          'summary': 'Healthy pollinator corridor.',
          'suggestions': ['Protect native hedgerows'],
        });
      };

      final assessment = Assessment(
        id: 'test-fallback',
        status: AssessmentStatus.submitted,
        createdAt: DateTime.now(),
      );

      // First run: calls Model 0 (fails with 429), then Model 1 (succeeds)
      final insight = await AiService.instance.generateAssessmentInsights(assessment);
      expect(insight.model, kAiModels[1]);
      expect(calledModels, [kAiModels[0], kAiModels[1]]);

      // Verify that Model 0 is recorded as exhausted in SharedPreferences
      final isExhausted = await AiService.instance.isModelExhausted(kAiModels[0]);
      expect(isExhausted, isTrue);

      // Verify that Model 1 is NOT exhausted
      final isModel1Exhausted = await AiService.instance.isModelExhausted(kAiModels[1]);
      expect(isModel1Exhausted, isFalse);

      // Second run: Model 0 must be skipped automatically!
      calledModels.clear();
      final secondInsight = await AiService.instance.generateAssessmentInsights(assessment);
      expect(secondInsight.model, kAiModels[1]);
      // Model 0 was remembered as exhausted and never called:
      expect(calledModels, [kAiModels[1]]);
    });

    test('503 and quota errors trigger fallback and exhaustion storage', () async {
      final calledModels = <String>[];

      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        calledModels.add(modelName);
        if (modelName == kAiModels[0]) {
          throw Exception('503 Service Unavailable');
        }
        if (modelName == kAiModels[1]) {
          throw Exception('Quota reached for this project');
        }
        // Model 2 succeeds
        return jsonEncode({
          'summary': 'Urban terrace garden analysis.',
          'suggestions': ['Add water dish with pebbles'],
        });
      };

      final assessment = Assessment(
        id: 'test-503',
        status: AssessmentStatus.submitted,
        createdAt: DateTime.now(),
      );

      final insight = await AiService.instance.generateAssessmentInsights(assessment);
      expect(insight.model, kAiModels[2]);
      expect(calledModels, [kAiModels[0], kAiModels[1], kAiModels[2]]);

      expect(await AiService.instance.isModelExhausted(kAiModels[0]), isTrue);
      expect(await AiService.instance.isModelExhausted(kAiModels[1]), isTrue);
      expect(await AiService.instance.isModelExhausted(kAiModels[2]), isFalse);
    });

    test('Expired exhaustion is cleared after midnight Pacific', () async {
      // Simulate an exhaustion that expired 1 hour ago
      final pastTime = DateTime.now().subtract(const Duration(hours: 1));
      await AiService.instance.markModelExhausted(kAiModels[0], customExpiry: pastTime);

      final isExhausted = await AiService.instance.isModelExhausted(kAiModels[0]);
      expect(isExhausted, isFalse);
    });
  });

  group('Friendly fallback message on failure path', () {
    test('When all models fail, friendly message is thrown instead of raw exception', () async {
      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        throw Exception('INTERNAL_SOCKET_ERROR_RAW_STACK_DUMP_404_SECRET_LEAK');
      };

      final assessment = Assessment(
        id: 'fail-all',
        status: AssessmentStatus.submitted,
        createdAt: DateTime.now(),
      );

      try {
        await AiService.instance.generateAssessmentInsights(assessment);
        fail('Expected AiException');
      } catch (e) {
        expect(e, isA<AiException>());
        expect(
          e.toString(),
          equals(kAiFallbackMessage),
        );
        expect(e.toString(), isNot(contains('SOCKET_ERROR')));
      }
    });
  });

  group('JSON Output parsing into AiInsight model', () {
    test('Parses full schema including habitatSuggestions and tips', () {
      const sampleJson = '''
      {
        "summary": "Rich pollinator oasis with abundant nectar.",
        "photoFindings": [
          "Healthy blooming lavender plants",
          "Sunlit exposure ideal for bees"
        ],
        "suggestions": [
          "Leave bare ground patches for solitary bees",
          "Avoid synthetic pesticides during flowering periods",
          "Plant night-blooming jasmine"
        ],
        "habitatSuggestions": [
          {"field": "flowers", "value": "High", "confidence": 0.85},
          {"field": "nesting", "value": "Medium", "confidence": 0.70},
          {"field": "water", "value": "Absent", "confidence": 0.90}
        ]
      }
      ''';

      final insight = AiService.instance.parseInsightResponse(sampleJson, 'gemini-2.5-flash');
      expect(insight.model, 'gemini-2.5-flash');
      expect(insight.summary, 'Rich pollinator oasis with abundant nectar.');
      expect(insight.photoFindings.length, 2);
      expect(insight.suggestions.length, 3);
      // Up to 2 AI tip bullets
      expect(insight.tips.length, 2);
      expect(insight.tips[0], 'Leave bare ground patches for solitary bees');
      expect(insight.tips[1], 'Avoid synthetic pesticides during flowering periods');

      // Habitat suggestions
      expect(insight.habitatSuggestions.length, 3);
      expect(insight.habitatSuggestions[0].chipLabel, 'AI suggests Flowers: High (85%) · Apply');
      expect(insight.habitatSuggestions[1].chipLabel, 'AI suggests Nesting: Medium (70%) · Apply');
      expect(insight.habitatSuggestions[2].chipLabel, 'AI suggests Water: Absent (90%) · Apply');
    });

    test('Parses JSON wrapped in markdown code blocks cleanly', () {
      const wrappedJson = '''
      ```json
      {
        "summary": "Clean markdown JSON response.",
        "suggestions": ["Tip 1"]
      }
      ```
      ''';

      final insight = AiService.instance.parseInsightResponse(wrappedJson, 'gemini-2.5-flash');
      expect(insight.summary, 'Clean markdown JSON response.');
      expect(insight.suggestions, ['Tip 1']);
    });
  });

  group('Monitor Step 2: Habitat suggestions and chips', () {
    testWidgets('Shows Analyse photos with AI button when photos exist, and applies chip on tap', (tester) async {
      Assessment currentDraft = Assessment(
        id: 'draft-1',
        activityPhotoPaths: ['path/to/habitat_photo.jpg'],
        createdAt: DateTime.now(),
      );

      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        return jsonEncode({
          'summary': 'Abundant floral patches observed.',
          'habitatSuggestions': [
            {'field': 'flowers', 'value': 'High', 'confidence': 0.80},
            {'field': 'nesting', 'value': 'Medium', 'confidence': 0.75},
          ],
        });
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Step2Habitat(
                    draft: currentDraft,
                    onDraftChanged: (updated) {
                      setState(() {
                        currentDraft = updated;
                      });
                    },
                    flowersKey: GlobalKey<ShakeWrapperState>(),
                    nestingKey: GlobalKey<ShakeWrapperState>(),
                    shelterKey: GlobalKey<ShakeWrapperState>(),
                    waterKey: GlobalKey<ShakeWrapperState>(),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "✨ Analyse photos with AI" button is visible because photos exist
      final analyseBtn = find.text('✨ Analyse photos with AI');
      expect(analyseBtn, findsOneWidget);

      // Flowers and Nesting are currently null (not selected)
      expect(currentDraft.flowers, isNull);
      expect(currentDraft.nesting, isNull);

      // Tap Analyse photos with AI
      await tester.tap(analyseBtn);
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify chips are displayed: "AI suggests Flowers: High (80%) · Apply"
      final flowersChip = find.text('AI suggests Flowers: High (80%) · Apply');
      final nestingChip = find.text('AI suggests Nesting: Medium (75%) · Apply');
      expect(flowersChip, findsOneWidget);
      expect(nestingChip, findsOneWidget);

      // Never auto-apply: draft is still empty before tapping Apply
      expect(currentDraft.flowers, isNull);

      // Tap Apply on flowers chip
      await tester.tap(flowersChip);
      await tester.pumpAndSettle();

      // Now flowers is filled with High!
      expect(currentDraft.flowers, Level.high);

      // Tap Apply on nesting chip
      await tester.tap(nestingChip);
      await tester.pumpAndSettle();

      // Now nesting is filled with Medium!
      expect(currentDraft.nesting, Level.medium);

      // The user can change it: tap Low on Flowers
      final lowOption = find.text('Low').first;
      await tester.tap(lowOption);
      await tester.pumpAndSettle();
      expect(currentDraft.flowers, Level.low);
    });
  });

  group('Results Screen: AI Insights Card & Regeneration', () {
    late FakeApiService fakeApi;

    setUp(() {
      fakeApi = FakeApiService();

      fakeApi.locations['loc-1'] = Location(
        id: 'loc-1',
        name: 'Botanical Garden',
        type: 'Park',
        address: 'Greams Road',
        createdAt: DateTime(2026, 1, 1),
      );

      const inputs = AssessmentInputs(
        visits: 15,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 28.0,
        humidityPct: 60.0,
        co2Ppm: 550.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final res = calculatePhi(inputs);
      fakeApi.assessments['res-assessment'] = Assessment(
        id: 'res-assessment',
        locationId: 'loc-1',
        status: AssessmentStatus.submitted,
        visits: 15,
        durationMinutes: 5,
        observedAt: DateTime(2026, 11, 14, 10, 0),
        weather: 'Sunny',
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 28.0,
        humidityPct: 60.0,
        co2Ppm: 550.0,
        riskLevel: RiskLevel.low,
        result: res,
        createdAt: DateTime(2026, 11, 14, 10, 0),
        submittedAt: DateTime(2026, 11, 14, 10, 5),
      );
    });

    testWidgets('Shows Generate insights button initially, generates insights, displays content & footer, and saves to assessment.ai', (tester) async {
      int generationCount = 0;
      AiService.instance.testModelRunner = ({
        required String modelName,
        required content,
        required schema,
      }) async {
        generationCount++;
        return jsonEncode({
          'summary': 'Superb habitat conditions supporting active pollinator populations (Run $generationCount).',
          'photoFindings': ['Cluster of blooming milkweed'],
          'suggestions': [
            'Maintain winter stem cover for cavity nesters',
            'Plant late-season asters'
          ],
        });
      };

      await tester.pumpWidget(
        Provider<ApiService>.value(
          value: fakeApi,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ResultsScreen(id: 'res-assessment'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is below "What to do next?" (F10: single title "Ecological insights")
      expect(find.text('What to do next?'), findsOneWidget);
      expect(find.text('Ecological insights'), findsOneWidget);

      // "Generate insights" button is visible
      final generateBtn = find.text('Generate insights');
      expect(generateBtn, findsOneWidget);

      // Tap "Generate insights"
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify summary, photo findings, up to 2 AI tips, and footer
      expect(find.textContaining('Superb habitat conditions supporting active pollinator populations (Run 1).'), findsOneWidget);
      expect(find.text('Photo findings'), findsOneWidget);
      expect(find.text('Cluster of blooming milkweed'), findsOneWidget);
      expect(find.text('AI tips'), findsOneWidget);
      expect(find.text('Maintain winter stem cover for cavity nesters'), findsOneWidget);
      expect(find.text('Plant late-season asters'), findsOneWidget);
      expect(find.text('AI-generated · may be inaccurate · model: ${kAiModels.first}'), findsOneWidget);

      // Verify that insight was saved to the assessment in ApiService
      final saved = fakeApi.assessments['res-assessment'];
      expect(saved?.ai, isNotNull);
      expect(saved?.ai?.summary, contains('Run 1'));

      // Regenerate icon button
      final regenBtn = find.byTooltip('Regenerate insights');
      expect(regenBtn, findsOneWidget);

      await tester.ensureVisible(regenBtn);
      await tester.tap(regenBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(generationCount, 2);
      expect(find.textContaining('Run 2'), findsOneWidget);
      expect(fakeApi.assessments['res-assessment']?.ai?.summary, contains('Run 2'));
    });
  });

  group('LocalDb SQLite Storage & 2026 Gemini Models', () {
    setUp(() {
      LocalDb.instance.inMemoryStorage = <String, String>{};
    });

    test('Gemini API Key can be saved, retrieved, and removed from local storage', () async {
      expect(await LocalDb.instance.hasGeminiApiKey(), isFalse);
      expect(await LocalDb.instance.getGeminiApiKey(), isNull);

      await LocalDb.instance.saveGeminiApiKey('AIzaSyTestKey_12345');
      expect(await LocalDb.instance.hasGeminiApiKey(), isTrue);
      expect(await LocalDb.instance.getGeminiApiKey(), 'AIzaSyTestKey_12345');

      await LocalDb.instance.deleteGeminiApiKey();
      expect(await LocalDb.instance.hasGeminiApiKey(), isFalse);
      expect(await LocalDb.instance.getGeminiApiKey(), isNull);
    });

    test('2026 Models list contains the latest Gemini generations in priority order', () {
      expect(kAiModels, contains('gemini-3.8-flash'));
      expect(kAiModels, contains('gemini-3.6-flash'));
      expect(kAiModels, contains('gemini-3.5-flash-lite'));
      expect(kAiModels, contains('gemini-3.1-flash-lite'));
      expect(kAiModels, contains('gemini-3-flash'));
      expect(kAiModels, contains('gemini-2.5-flash'));
      expect(kAiModels, contains('gemini-2.5-flash-lite'));
      expect(kAiModels.first, 'gemini-3.8-flash');
    });

    test('generateWithFallback throws user guidance when no API key is configured', () async {
      await LocalDb.instance.deleteGeminiApiKey();
      AiService.instance.testModelRunner = null;

      final assessment = Assessment(
        id: 'no-key-test',
        status: AssessmentStatus.submitted,
        createdAt: DateTime.now(),
      );

      expect(
        () async => await AiService.instance.generateAssessmentInsights(assessment),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Profile & Settings'),
          ),
        ),
      );
    });
  });
}
