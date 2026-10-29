/// Deterministic free-time rules for participant planning ("Plan my free
/// time"). Pure Dart: no widgets, no network.
///
/// The server (`save_personal_free_time_plan`) applies the SAME rules again
/// and is the authority; this copy only gives participants immediate,
/// understandable feedback before they save. The AI never decides
/// availability.
library;

/// Minutes since midnight, e.g. 9:30 → 570.
typedef DayMinute = int;

DayMinute parseHm(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String formatHm(DayMinute m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Why a period is not available.
enum BusyKind { official, personal, unavailable }

class BusyPeriod {
  final DayMinute start;
  final DayMinute end;
  final BusyKind kind;
  final String title;

  /// The official activity has no end time; the server blocked it up to
  /// the next official activity (conservative).
  final bool timeUnknown;

  const BusyPeriod({
    required this.start,
    required this.end,
    required this.kind,
    required this.title,
    this.timeUnknown = false,
  });

  bool overlaps(DayMinute s, DayMinute e) => s < end && start < e;
}

class FreeSlot {
  final DayMinute start;
  final DayMinute end;
  const FreeSlot(this.start, this.end);
  int get minutes => end - start;
  bool contains(DayMinute s, DayMinute e) => s >= start && e <= end;
  @override
  String toString() => '${formatHm(start)}–${formatHm(end)}';
}

/// Everything the server says about one participant/day.
class PlanningDay {
  final DateTime date;
  final DayMinute windowStart;
  final DayMinute windowEnd;

  /// Window start, or the current time for today.
  final DayMinute earliestStart;

  /// The day cannot be planned at all (whole-day restriction, or an
  /// official activity without a time). Staff need to clarify.
  final bool blocked;
  final String? blockedReason;
  final List<BusyPeriod> busy;

  const PlanningDay({
    required this.date,
    required this.windowStart,
    required this.windowEnd,
    required this.earliestStart,
    required this.blocked,
    this.blockedReason,
    this.busy = const [],
  });

  factory PlanningDay.fromJson(DateTime date, Map<String, dynamic> j) =>
      PlanningDay(
        date: date,
        windowStart: parseHm(j['windowStart'] as String),
        windowEnd: parseHm(j['windowEnd'] as String),
        earliestStart: parseHm(j['earliestStart'] as String),
        blocked: j['blocked'] == true,
        blockedReason: j['blockedReason'] as String?,
        busy: [
          for (final b in (j['busy'] as List? ?? const []))
            BusyPeriod(
              start: parseHm((b as Map)['start'] as String),
              end: parseHm(b['end'] as String),
              kind: BusyKind.values.byName(b['kind'] as String),
              title: b['title'] as String,
              timeUnknown: b['timeUnknown'] == true,
            ),
        ]..sort((a, b) => a.start.compareTo(b.start)),
      );

  /// Free periods inside the planning window (from [earliestStart]).
  List<FreeSlot> get freeSlots {
    if (blocked) return const [];
    final slots = <FreeSlot>[];
    var cursor = earliestStart;
    for (final b in busy) {
      if (b.end <= cursor) continue;
      if (b.start > cursor) slots.add(FreeSlot(cursor, b.start.clamp(cursor, windowEnd)));
      if (b.end > cursor) cursor = b.end;
      if (cursor >= windowEnd) break;
    }
    if (cursor < windowEnd) slots.add(FreeSlot(cursor, windowEnd));
    return [for (final s in slots) if (s.minutes >= FreeTimeRules.minSlotMinutes) s];
  }

  bool get hasFreeTime => freeSlots.isNotEmpty;
}

/// One activity the participant wants to add. Times may be missing until
/// the participant chooses them; nothing is invented.
class DraftActivity {
  final String title;
  final DayMinute? start;
  final DayMinute? end;
  final String iconKey;
  final String? pictogramUrl;

  /// The AI read this for another day than the one being planned.
  final DateTime? otherDay;

  const DraftActivity({
    required this.title,
    this.start,
    this.end,
    this.iconKey = 'event',
    this.pictogramUrl,
    this.otherDay,
  });

  DraftActivity copyWith({
    String? title,
    DayMinute? start,
    DayMinute? end,
    bool clearEnd = false,
    bool clearOtherDay = false,
  }) =>
      DraftActivity(
        title: title ?? this.title,
        start: start ?? this.start,
        end: clearEnd ? null : (end ?? this.end),
        iconKey: iconKey,
        pictogramUrl: pictogramUrl,
        otherDay: clearOtherDay ? null : otherDay,
      );
}

enum DraftProblem {
  noTitle,
  wrongDay,
  needsStart,
  needsEnd,
  endBeforeStart,
  outsideWindow,
  overlapsBusy,
  overlapsOtherDraft,
}

class DraftCheck {
  final DraftProblem? problem;

  /// For [DraftProblem.overlapsBusy]: what it collides with.
  final BusyPeriod? conflict;
  const DraftCheck([this.problem, this.conflict]);
  bool get ok => problem == null;
}

abstract final class FreeTimeRules {
  /// Gaps shorter than this are not offered as free slots.
  static const minSlotMinutes = 15;

  /// Durations the participant can pick when they did not say one.
  static const durationChoices = [15, 30, 60, 90, 120];

  /// Checks every draft against the day and against the other drafts.
  static List<DraftCheck> validate(PlanningDay day, List<DraftActivity> drafts) {
    final checks = <DraftCheck>[];
    final accepted = <(DayMinute, DayMinute)>[];
    for (final d in drafts) {
      checks.add(_check(day, d, accepted));
      if (checks.last.ok) accepted.add((d.start!, d.end!));
    }
    return checks;
  }

  static DraftCheck _check(
      PlanningDay day, DraftActivity d, List<(DayMinute, DayMinute)> accepted) {
    if (d.title.trim().isEmpty) return const DraftCheck(DraftProblem.noTitle);
    if (d.otherDay != null) return const DraftCheck(DraftProblem.wrongDay);
    final s = d.start, e = d.end;
    if (s == null) return const DraftCheck(DraftProblem.needsStart);
    if (e == null) return const DraftCheck(DraftProblem.needsEnd);
    if (e <= s) return const DraftCheck(DraftProblem.endBeforeStart);
    if (s < day.earliestStart || e > day.windowEnd) {
      return const DraftCheck(DraftProblem.outsideWindow);
    }
    for (final b in day.busy) {
      if (b.overlaps(s, e)) return DraftCheck(DraftProblem.overlapsBusy, b);
    }
    for (final (otherStart, otherEnd) in accepted) {
      if (s < otherEnd && otherStart < e) return const DraftCheck(DraftProblem.overlapsOtherDraft);
    }
    return const DraftCheck();
  }

  static bool canSave(PlanningDay day, List<DraftActivity> drafts) =>
      !day.blocked &&
      drafts.isNotEmpty &&
      validate(day, drafts).every((c) => c.ok);

  /// Short, calm explanation for the participant.
  static String explain(DraftCheck c, PlanningDay day) => switch (c.problem) {
        null => 'Fits in your free time.',
        DraftProblem.noTitle => 'Give it a name.',
        DraftProblem.wrongDay => 'This sounds like another day. Choose a time for this day or remove it.',
        DraftProblem.needsStart => 'When does it start? Choose a time.',
        DraftProblem.needsEnd => 'How long does it take? Choose a length.',
        DraftProblem.endBeforeStart => 'It has to end after it starts.',
        DraftProblem.outsideWindow =>
          'You can plan between ${formatHm(day.earliestStart)} and ${formatHm(day.windowEnd)}.',
        DraftProblem.overlapsBusy => switch (c.conflict!.kind) {
            BusyKind.official =>
              'This time is taken by "${c.conflict!.title}". Choose another free time.',
            BusyKind.personal =>
              'You already planned "${c.conflict!.title}" then. Choose another free time.',
            BusyKind.unavailable =>
              'This time is not available (${c.conflict!.title}). Choose another free time.',
          },
        DraftProblem.overlapsOtherDraft => 'This overlaps another activity in your plan.',
      };
}
