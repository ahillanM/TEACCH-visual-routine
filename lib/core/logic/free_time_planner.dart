import '../ai/event_draft_generator.dart';
import '../models/activity_category.dart';
import '../models/library_items.dart';
import '../models/scheduled_event.dart';
import '../models/visual_ref.dart';

/// A leisure idea a participant can pick when adding to their free time.
class FreeTimeIdea {
  final String title;
  final VisualRef visual;
  const FreeTimeIdea(this.title, this.visual);
}

/// Places a participant's own activities inside one free-time window.
///
/// Pure logic (no Flutter, no network) so it is easy to test. Activities
/// never leave the window, so staff-planned activities are never touched.
abstract final class FreeTimePlanner {
  static const int defaultMinutes = 30;
  static const int minMinutes = 10;

  /// Suggestions shown in "Do it myself".
  static const ideas = [
    FreeTimeIdea('Read a Book', VisualRef(symbol: 'read')),
    FreeTimeIdea('Listen to Music', VisualRef(symbol: 'music')),
    FreeTimeIdea('Go for a Walk', VisualRef(symbol: 'walk')),
    FreeTimeIdea('Play a Game', VisualRef(symbol: 'games')),
    FreeTimeIdea('Call My Family', VisualRef(symbol: 'phone')),
    FreeTimeIdea('Draw or Paint', VisualRef(symbol: 'art')),
    FreeTimeIdea('Rest', VisualRef(symbol: 'relax')),
  ];

  /// Splits "play guitar, then read and rest" into separate ideas.
  /// Used when the AI service is unavailable or returns nothing.
  static List<String> splitIdeas(String text) => text
      .split(
        RegExp(r',|;|\n|\band then\b|\bthen\b|\band\b', caseSensitive: false),
      )
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map(capitalize)
      .toList();

  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Picks a symbol for a free-text title (falls back to "free").
  static VisualRef visualFor(String title, List<LibraryActivity> library) {
    final lower = title.toLowerCase();
    for (final a in library) {
      if (lower.contains(a.name.toLowerCase())) return a.visual;
    }
    for (final idea in ideas) {
      final key = idea.title.toLowerCase().split(' ').last;
      if (lower.contains(key)) return idea.visual;
    }
    const keywords = {
      'music': 'music',
      'guitar': 'music',
      'sing': 'music',
      'walk': 'walk',
      'outside': 'walk',
      'read': 'read',
      'book': 'read',
      'call': 'phone',
      'phone': 'phone',
      'draw': 'art',
      'paint': 'art',
      'game': 'games',
      'play': 'games',
      'sport': 'sport',
      'football': 'sport',
      'gym': 'sport',
      'rest': 'relax',
      'relax': 'relax',
      'sleep': 'sleep',
      'cook': 'kitchen',
      'eat': 'meal',
      'snack': 'meal',
    };
    for (final MapEntry(:key, :value) in keywords.entries) {
      if (lower.contains(key)) return VisualRef(symbol: value);
    }
    return const VisualRef(symbol: 'free');
  }

  /// Lays [titles] out one after another from [from], each with its wished
  /// length (default [defaultMinutes]), shrinking them evenly if they do not
  /// all fit before [until]. Items that would be shorter than [minMinutes]
  /// are dropped.
  static List<EventProposal> layOut({
    required List<({String title, int minutes, VisualRef? visual})> items,
    required DateTime from,
    required DateTime until,
  }) {
    final available = until.difference(from).inMinutes;
    if (items.isEmpty || available < minMinutes) return const [];
    final wanted = items.fold<int>(0, (sum, i) => sum + i.minutes);
    final scale = wanted > available ? available / wanted : 1.0;

    final result = <EventProposal>[];
    var cursor = from;
    for (final item in items) {
      final minutes = (item.minutes * scale).floor();
      if (minutes < minMinutes) continue;
      final end = cursor.add(Duration(minutes: minutes));
      if (end.isAfter(until)) break;
      result.add(
        EventProposal(
          title: item.title,
          start: cursor,
          end: end,
          category: ActivityCategory.personal,
          visual: item.visual,
        ),
      );
      cursor = end;
    }
    return result;
  }

  /// Turns AI proposals (or, if there are none, the split text) into
  /// activities that fit the free-time window.
  static List<EventProposal> fromText({
    required String text,
    required List<EventProposal> aiProposals,
    required DateTime from,
    required DateTime until,
    required List<LibraryActivity> library,
  }) {
    final items = aiProposals.isNotEmpty
        ? [
            for (final p in aiProposals)
              (
                title: capitalize(p.title),
                minutes: p.end
                    .difference(p.start)
                    .inMinutes
                    .clamp(minMinutes, 120),
                visual:
                    p.libraryMatch?.visual ??
                    p.visual ??
                    visualFor(p.title, library),
              ),
          ]
        : [
            for (final t in splitIdeas(text))
              (
                title: t,
                minutes: defaultMinutes,
                visual: visualFor(t, library),
              ),
          ];
    return layOut(items: items, from: from, until: until);
  }

  /// The event that is stored for one accepted proposal.
  static ScheduledEvent toEvent(
    EventProposal p, {
    required String id,
    required String participantId,
  }) => ScheduledEvent(
    id: id,
    title: p.title,
    category: ActivityCategory.personal,
    start: p.start,
    end: p.end,
    visual: p.visual ?? const VisualRef(symbol: 'free'),
    assignedParticipantIds: {participantId},
    createdByParticipantId: participantId,
  );

  /// First usable start inside a free-time window: never in the past,
  /// rounded up to the next 5 minutes.
  static DateTime earliestStart(DateTime windowStart, DateTime now) {
    if (!now.isAfter(windowStart)) return windowStart;
    final rounded = now.minute % 5 == 0 && now.second == 0
        ? now
        : DateTime(
            now.year,
            now.month,
            now.day,
            now.hour,
            (now.minute ~/ 5 + 1) * 5,
          );
    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }
}
