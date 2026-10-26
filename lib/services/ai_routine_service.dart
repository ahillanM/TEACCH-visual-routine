import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schedule_item.dart';

class AiRoutineService {
  // Replace with your Gemini API key from aistudio.google.com
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';

  /// Converts plain text (e.g., "wake up, wash up, get dressed, have breakfast")
  /// into a structured visual ScheduleItem with timed sub-steps.
  static Future<ScheduleItem> generateRoutineFromText(String plainTextInput) async {
    // Smart Fallback if API key is not configured yet
    if (_apiKey == 'YOUR_GEMINI_API_KEY' || _apiKey.isEmpty) {
      return _localFallbackParser(plainTextInput);
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      );

      final prompt = '''
Convert this user input into a structured visual routine for a TEACCH planner app: "$plainTextInput"
Return ONLY valid JSON with this exact structure:
{
  "title": "Short English routine title",
  "timeRange": "Estimated duration (e.g., 30 Min)",
  "arasaacKeyword": "single simple English noun for an icon (e.g., breakfast, toothbrush, bed, book)",
  "subSteps": [
    {"title": "Step 1 action in clear English", "durationMin": 5},
    {"title": "Step 2 action in clear English", "durationMin": 10}
  ]
}
''';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          }
        }),
      );

      final data = jsonDecode(response.body);
      final rawJsonText = data['candidates'][0]['content']['parts'][0]['text'];
      final parsed = jsonDecode(rawJsonText);

      final keyword = parsed['arasaacKeyword'] ?? 'calendar';
      final pictogramUrl = await _fetchPictogramUrl(keyword);

      return ScheduleItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed['title'] ?? 'Personal Routine',
        category: 'PERSONAL',
        colorHex: 0xFF805AD5, // Purple = Personal Routine
        timeRange: parsed['timeRange'] ?? '25 Min',
        locationName: 'Personal Space',
        staffName: 'Independent',
        pictogramUrl: pictogramUrl,
        createdByStaff: false,
        subSteps: (parsed['subSteps'] as List)
            .map((s) => SubStep(
                  title: s['title'],
                  durationMin: s['durationMin'] ?? 5,
                ))
            .toList(),
      );
    } catch (_) {
      return _localFallbackParser(plainTextInput);
    }
  }

  /// Splits plain text by commas or "and" so the demo works even offline or without an API key
  static Future<ScheduleItem> _localFallbackParser(String input) async {
    final parts = input
        .split(RegExp(r'[,;\n]+|\band\b'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final steps = parts.isEmpty
        ? [SubStep(title: input.trim(), durationMin: 10)]
        : parts.map((p) => SubStep(title: p, durationMin: 10)).toList();

    final totalMin = steps.length * 10;

    return ScheduleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Personal Routine (${steps.length} Steps)',
      category: 'PERSONAL',
      colorHex: 0xFF805AD5, // Purple = Personal Routine
      timeRange: 'Approx. $totalMin Min',
      locationName: 'Personal Space',
      staffName: 'Independent',
      pictogramUrl: 'https://static.arasaac.org/pictograms/2325/2325_500.png',
      createdByStaff: false,
      subSteps: steps,
    );
  }

  static Future<String> _fetchPictogramUrl(String keyword) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.arasaac.org/v1/pictograms/en/search/$keyword'),
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final id = list[0]['_id'];
          return 'https://static.arasaac.org/pictograms/$id/${id}_500.png';
        }
      }
    } catch (_) {}
    return 'https://static.arasaac.org/pictograms/2325/2325_500.png';
  }
}