import '../models/library_items.dart';
import '../time/time_format.dart';

/// One activity proposed from free text. Always reviewed by staff before it
/// becomes a draft – AI never publishes.
class EventProposal {
  final String title;
  final DateTime start;
  final DateTime end;
  final LibraryActivity? libraryMatch;

  const EventProposal({
    required this.title,
    required this.start,
    required this.end,
    this.libraryMatch,
  });

  EventProposal copyWith({String? title, DateTime? start, DateTime? end}) {
    return EventProposal(
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      libraryMatch: libraryMatch,
    );
  }
}

/// A generator failure with a message that can be shown to staff.
class EventDraftException implements Exception {
  final String message;
  const EventDraftException(this.message);
  @override
  String toString() => message;
}

/// Boundary for "Build with AI". A real implementation (e.g. Gemini via the
/// backend team's service) can replace the mock without touching the UI.
abstract class EventDraftGenerator {
  Future<List<EventProposal>> propose(
    String text, {
    required DateTime today,
    required List<LibraryActivity> library,
  });
}

/// MOCK: rule-based parser, no network and no external AI.
///
/// Understands phrases like "Tomorrow woodworking at 9, lunch at 12 and
/// physiotherapy at 2". Hours 1–6 are read as afternoon.
class MockEventDraftGenerator implements EventDraftGenerator {
  static const int _afternoonCutoffHour = 7;
  static const int _defaultDurationMin = 60;

  const MockEventDraftGenerator();

  @override
  Future<List<EventProposal>> propose(
    String text, {
    required DateTime today,
    required List<LibraryActivity> library,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    var day = TimeFormat.dateOnly(today);
    var input = text.trim();
    final tomorrow = RegExp(r'\btomorrow\b', caseSensitive: false);
    if (tomorrow.hasMatch(input)) {
      day = day.add(const Duration(days: 1));
      input = input.replaceAll(tomorrow, '');
    }

    final timePattern =
        RegExp(r'\bat\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?', caseSensitive: false);
    final proposals = <EventProposal>[];

    for (final raw in input.split(RegExp(r',|\band\b|;|\n'))) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final match = timePattern.firstMatch(part);
      if (match == null) continue;

      var hour = int.parse(match.group(1)!);
      final minute = int.tryParse(match.group(2) ?? '') ?? 0;
      final suffix = match.group(3)?.toLowerCase();
      if (suffix == 'pm' && hour < 12) hour += 12;
      if (suffix == null && hour < _afternoonCutoffHour) hour += 12;

      final title = _titleCase(part.replaceAll(timePattern, '').trim());
      if (title.isEmpty) continue;
      final match0 = _matchLibrary(title, library);
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      final duration = match0?.defaultDurationMin ?? _defaultDurationMin;
      proposals.add(EventProposal(
        title: match0?.name ?? title,
        start: start,
        end: start.add(Duration(minutes: duration)),
        libraryMatch: match0,
      ));
    }
    proposals.sort((a, b) => a.start.compareTo(b.start));
    return proposals;
  }

  static LibraryActivity? _matchLibrary(
    String title,
    List<LibraryActivity> library,
  ) {
    final lower = title.toLowerCase();
    for (final a in library) {
      final name = a.name.toLowerCase();
      final firstWord = name.split(' ').first;
      if (lower.contains(firstWord) || name.contains(lower)) return a;
    }
    return null;
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
