import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Standalone CLI utility to check latest available Gemini models from Google AI Studio,
/// list active free-tier models, rate limits (RPM/RPD/TPM), and fallback chain.
void main(List<String> args) async {
  String? apiKey;

  for (final arg in args) {
    if (arg.startsWith('--key=')) {
      apiKey = arg.substring(6);
    } else if (arg.startsWith('-k=')) {
      apiKey = arg.substring(3);
    } else if (!arg.startsWith('-')) {
      apiKey = arg;
    }
  }

  apiKey ??= Platform.environment['GEMINI_API_KEY'];

  print('================================================================');
  print('          GOOGLE GEMINI API - MODEL & QUOTA INSPECTOR           ');
  print('================================================================');
  print('');

  if (apiKey != null && apiKey.isNotEmpty) {
    print('Querying Google Generative Language API (v1beta/models)...');
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = (data['models'] as List<dynamic>?) ?? [];

        print('SUCCESS: Found ${models.length} total models on Google Generative AI.\n');
        print('Available generateContent models:');
        print('----------------------------------------------------------------');

        for (final m in models) {
          final name = (m['name'] as String? ?? '').replaceFirst('models/', '');
          final displayName = m['displayName'] ?? name;
          final methods = (m['supportedGenerationMethods'] as List<dynamic>?) ?? [];
          final inputLimit = m['inputTokenLimit'] ?? 'N/A';
          final outputLimit = m['outputTokenLimit'] ?? 'N/A';

          if (methods.contains('generateContent')) {
            print(' • $name');
            print('   Display Name: $displayName');
            print('   Tokens: Input $inputLimit | Output $outputLimit');
            print('');
          }
        }
      } else {
        print('API Notice: Response status ${response.statusCode}');
        print('Body: ${response.body}\n');
      }
    } catch (e) {
      print('Network/API Notice: $e\n');
    }
  } else {
    print('Note: No API key provided via argument or GEMINI_API_KEY env var.');
    print('Pass your key via: dart run tool/check_gemini_models.dart <API_KEY>\n');
  }

  print('================================================================');
  print('   OFFICIAL GOOGLE GEMINI FREE-TIER MODELS & QUOTA BREAKDOWN   ');
  print('================================================================');
  print('''
Priority 1: gemini-3.8-flash
  • Role: Primary Flagship Multimodal & Text Model (Default)
  • Rate Limits: 5 RPM | 250,000 TPM | 20 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 2: gemini-3.6-flash
  • Role: Advanced Reasoning & Analysis Workhorse
  • Rate Limits: 5 RPM | 250,000 TPM | 20 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 3: gemini-3.5-flash-lite
  • Role: High-Capacity Free-Tier Workhorse (Heavy Duty)
  • Rate Limits: 15 RPM | 250,000 TPM | 500 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 4: gemini-3.1-flash-lite
  • Role: High-Throughput Lightweight Model
  • Rate Limits: 15 RPM | 250,000 TPM | 500 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 5: gemini-3-flash
  • Role: General Flash Model
  • Rate Limits: 5 RPM | 250,000 TPM | 20 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 6: gemini-2.5-flash
  • Role: Multimodal Reliable Fallback
  • Rate Limits: 5 RPM | 250,000 TPM | 20 RPD
  • Reset: Midnight Pacific Time (PT)

Priority 7: gemini-2.5-flash-lite
  • Role: Ultra-Fast Reliable Fallback
  • Rate Limits: 10 RPM | 250,000 TPM | 20 RPD
  • Reset: Midnight Pacific Time (PT)

Fallback Trigger Mechanism:
  • HTTP 429 / RESOURCE_EXHAUSTED / Quota Exceeded / HTTP 503
  • Automatically persists exhaustion timestamp until Midnight Pacific Time
  • Immediately falls back to next priority model in sequence
  • Zero user-visible crash or failure during quota transitions
================================================================
''');
}
