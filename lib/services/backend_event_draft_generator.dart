import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/ai/event_draft_generator.dart';
import '../core/models/activity_category.dart';
import '../core/models/library_items.dart';
import '../core/models/visual_ref.dart';
import '../core/time/time_format.dart';

/// "Build with AI" through the FastAPI backend (`POST /ai/generate-routine`).
///
/// The backend calls OpenRouter and validates the result; the API key never
/// reaches the app. The response is always a draft: staff review it and the
/// app only writes to Supabase when staff publish.
class BackendEventDraftGenerator implements EventDraftGenerator {
  final Uri baseUrl;
  final String apiKey;
  final http.Client _client;

  static const _timeout = Duration(seconds: 90);
  static const _defaultDurationMin = 60;

  BackendEventDraftGenerator({
    required this.baseUrl,
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Raw `POST /ai/generate-routine` response (a validated DRAFT proposal).
  /// Shared by staff "Build with AI" and participant free-time planning, so
  /// typed and dictated text always use the same pipeline. [existingItems]
  /// ({title, date, startTime, endTime}) let the backend flag conflicts; the
  /// app and the database still decide availability themselves.
  Future<Map<String, dynamic>> generateRoutine({
    required String instruction,
    required DateTime referenceDate,
    required String requesterRole,
    List<Map<String, String?>> existingItems = const [],
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            baseUrl.resolve('/ai/generate-routine'),
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
            },
            body: jsonEncode({
              'instruction': instruction,
              'referenceDate': _date(referenceDate),
              'requesterRole': requesterRole,
              if (existingItems.isNotEmpty) 'existingItems': existingItems,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const EventDraftException(
        'The AI service cannot be reached. Is the backend running?',
      );
    }

    final body = _decode(response.body);
    if (response.statusCode != 200) {
      final detail = body['detail'];
      throw EventDraftException(
        detail is Map && detail['message'] is String
            ? detail['message'] as String
            : 'The AI service failed (HTTP ${response.statusCode}).',
      );
    }
    return body;
  }

  @override
  Future<List<EventProposal>> propose(
    String text, {
    required DateTime today,
    required List<LibraryActivity> library,
  }) async {
    final body = await generateRoutine(
      instruction: text,
      referenceDate: today,
      requesterRole: 'staff',
    );

    final day =
        DateTime.tryParse((body['date'] as String?) ?? '') ??
        TimeFormat.dateOnly(today);
    final pending = <Future<EventProposal>>[];
    for (final item in (body['items'] as List? ?? const [])) {
      final m = item as Map<String, dynamic>;
      final startTime = m['startTime'] as String?;
      if (startTime == null) continue; // staff add untimed items manually
      final date = DateTime.tryParse((m['date'] as String?) ?? '') ?? day;
      final start = _at(date, startTime);
      final endTime = m['endTime'] as String?;
      final steps = (m['subSteps'] as List? ?? const [])
          .map((s) => (s as Map)['durationMin'] as int?)
          .whereType<int>();
      final stepsMin = steps.fold(0, (a, b) => a + b);
      var end = endTime == null
          ? start.add(
              Duration(minutes: stepsMin > 0 ? stepsMin : _defaultDurationMin),
            )
          : _at(date, endTime);
      if (!end.isAfter(start)) {
        end = start.add(const Duration(minutes: _defaultDurationMin));
      }
      final title = m['title'] as String;
      final match = _matchLibrary(title, library);
      final category = m['category'] is String
          ? ActivityCategory.fromLegacyCode(m['category'] as String)
          : null;
      final keyword = (m['pictogramKeyword'] as String?)?.trim().toLowerCase();
      pending.add(
        (match != null ? Future.value(match.visual) : visualFor(keyword)).then(
          (visual) => EventProposal(
            title: title,
            start: start,
            end: end,
            libraryMatch: match,
            category: category,
            visual: visual,
          ),
        ),
      );
    }
    final proposals = await Future.wait(pending);
    if (proposals.isEmpty) {
      final issues = [
        for (final i in (body['issues'] as List? ?? const []))
          if ((i as Map)['severity'] == 'error') i['message'] as String,
      ];
      throw EventDraftException(
        issues.isNotEmpty ? issues.join('\n') : 'No activities with a time were found. Please add times, e.g. "lunch at 12".',
      );
    }
    proposals.sort((a, b) => a.start.compareTo(b.start));
    return proposals;
  }

  /// Icon key for the AI's pictogram keyword, plus an ARASAAC pictogram if the
  /// public ARASAAC search finds one. Only the keyword is sent (no names or
  /// ids); any failure falls back to the icon.
  Future<VisualRef> visualFor(String? keyword) async {
    if (keyword == null || keyword.isEmpty) {
      return const VisualRef(symbol: 'event');
    }
    final symbol = _symbolFor(keyword);
    try {
      final r = await _client
          .get(
            Uri.https('api.arasaac.org', '/v1/pictograms/en/search/$keyword'),
          )
          .timeout(_arasaacTimeout);
      final list = r.statusCode == 200 ? jsonDecode(r.body) : null;
      if (list is List && list.isNotEmpty && list.first['_id'] is int) {
        return VisualRef.arasaac(symbol, list.first['_id'] as int);
      }
    } catch (_) {
      // Offline or ARASAAC down: the icon is enough.
    }
    return VisualRef(symbol: symbol);
  }

  static const _arasaacTimeout = Duration(seconds: 4);

  /// Keyword fragments → `SymbolIcons` keys.
  static const _symbols = {
    'teeth': 'teeth',
    'tooth': 'teeth',
    'brush': 'teeth',
    'breakfast': 'breakfast',
    'lunch': 'meal',
    'dinner': 'meal',
    'meal': 'meal',
    'food': 'meal',
    'eat': 'meal',
    'snack': 'meal',
    'bed': 'sleep',
    'sleep': 'sleep',
    'alarm': 'wake',
    'wake': 'wake',
    'shower': 'shower',
    'wash': 'shower',
    'bath': 'shower',
    'cloth': 'dress',
    'dress': 'dress',
    'shirt': 'dress',
    'wood': 'carpentry',
    'carpent': 'carpentry',
    'workshop': 'carpentry',
    'tool': 'carpentry',
    'metal': 'metal',
    'machine': 'metal',
    'book': 'study',
    'study': 'study',
    'homework': 'study',
    'school': 'study',
    'bus': 'bus',
    'travel': 'bus',
    'train': 'bus',
    'kitchen': 'kitchen',
    'cook': 'kitchen',
    'sport': 'sport',
    'football': 'sport',
    'gym': 'sport',
    'swim': 'sport',
    'therap': 'therapy',
    'physio': 'therapy',
    'doctor': 'therapy',
    'game': 'games',
    'relax': 'relax',
    'rest': 'relax',
    'break': 'relax',
    'garden': 'relax',
    'meeting': 'meeting',
    'group': 'meeting',
    'office': 'office',
    'computer': 'office',
  };

  static String _symbolFor(String keyword) {
    for (final e in _symbols.entries) {
      if (keyword.contains(e.key)) return e.value;
    }
    return 'event';
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : const {};
    } catch (_) {
      return const {};
    }
  }

  static LibraryActivity? _matchLibrary(
    String title,
    List<LibraryActivity> library,
  ) {
    final lower = title.toLowerCase();
    for (final a in library) {
      final name = a.name.toLowerCase();
      if (lower.contains(name.split(' ').first) || name.contains(lower)) {
        return a;
      }
    }
    return null;
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _at(DateTime day, String hhmm) {
    final p = hhmm.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(p[0]),
      int.parse(p[1]),
    );
  }
}
