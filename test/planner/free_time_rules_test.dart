import 'package:bbw_visual_routine/core/logic/free_time.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningDay day({
  List<BusyPeriod> busy = const [],
  String earliest = '07:00',
  bool blocked = false,
}) =>
    PlanningDay(
      date: DateTime(2026, 11, 14),
      windowStart: parseHm('07:00'),
      windowEnd: parseHm('22:00'),
      earliestStart: parseHm(earliest),
      blocked: blocked,
      blockedReason: blocked ? 'ask staff' : null,
      busy: busy,
    );

BusyPeriod busy(String s, String e, [BusyKind k = BusyKind.official, String t = 'Workshop']) =>
    BusyPeriod(start: parseHm(s), end: parseHm(e), kind: k, title: t);

DraftActivity draft(String title, [String? s, String? e]) => DraftActivity(
    title: title, start: s == null ? null : parseHm(s), end: e == null ? null : parseHm(e));

void main() {
  test('an empty day is free inside the planning window only', () {
    expect(day().freeSlots.map((s) => s.toString()), ['07:00–22:00']);
  });

  test('official 09:00–15:00 leaves only the time around it', () {
    final d = day(busy: [busy('09:00', '15:00')]);
    expect(d.freeSlots.map((s) => s.toString()), ['07:00–09:00', '15:00–22:00']);
  });

  test('a weekend with an official activity at 11:00 is not fully free', () {
    final d = day(busy: [busy('11:00', '12:00', BusyKind.official, 'Sports club')]);
    expect(d.freeSlots.map((s) => s.toString()), ['07:00–11:00', '12:00–22:00']);
    final c = FreeTimeRules.validate(d, [draft('Football', '11:30', '12:30')]).single;
    expect(c.problem, DraftProblem.overlapsBusy);
    expect(FreeTimeRules.explain(c, d), contains('Sports club'));
  });

  test('today starts at the current time; tiny gaps are not offered', () {
    final d = day(earliest: '15:43', busy: [busy('16:00', '18:00'), busy('18:10', '19:00')]);
    expect(d.freeSlots.map((s) => s.toString()), ['15:43–16:00', '19:00–22:00']);
    expect(FreeTimeRules.validate(d, [draft('Snack', '15:00', '15:30')]).single.problem,
        DraftProblem.outsideWindow);
  });

  test('a blocked day has no free time and cannot be saved', () {
    final d = day(blocked: true);
    expect(d.freeSlots, isEmpty);
    expect(FreeTimeRules.canSave(d, [draft('Walk', '10:00', '11:00')]), isFalse);
  });

  test('times are never invented: missing start/end must be chosen', () {
    final checks = FreeTimeRules.validate(day(), [draft('Movie'), draft('Breakfast', '08:00')]);
    expect(checks.map((c) => c.problem), [DraftProblem.needsStart, DraftProblem.needsEnd]);
    expect(FreeTimeRules.canSave(day(), [draft('Breakfast', '08:00')]), isFalse);
  });

  test('conflicts: official, own earlier plan, staff restriction, other draft', () {
    final d = day(busy: [
      busy('09:00', '10:00'),
      busy('12:00', '13:00', BusyKind.personal, 'Lunch with Mia'),
      busy('16:00', '18:00', BusyKind.unavailable, 'Room cleaning'),
    ]);
    final checks = FreeTimeRules.validate(d, [
      draft('A', '09:30', '10:30'),
      draft('B', '12:30', '13:30'),
      draft('C', '17:00', '17:30'),
      draft('D', '19:00', '20:00'),
      draft('E', '19:30', '20:30'),
      draft('F', '20:30', '21:00'),
    ]);
    expect(checks.map((c) => c.problem), [
      DraftProblem.overlapsBusy,
      DraftProblem.overlapsBusy,
      DraftProblem.overlapsBusy,
      null,
      DraftProblem.overlapsOtherDraft,
      null,
    ]);
    expect(checks[1].conflict!.kind, BusyKind.personal);
    expect(checks[2].conflict!.kind, BusyKind.unavailable);
  });

  test('touching periods are fine; ending after the window is not', () {
    final d = day(busy: [busy('09:00', '10:00')]);
    expect(FreeTimeRules.canSave(d, [draft('Before', '08:00', '09:00'), draft('After', '10:00', '11:00')]),
        isTrue);
    expect(FreeTimeRules.validate(d, [draft('Late', '21:30', '22:30')]).single.problem,
        DraftProblem.outsideWindow);
  });

  test('another day from the AI must be resolved first', () {
    final d = DraftActivity(
        title: 'Cinema', start: parseHm('20:00'), end: parseHm('22:00'), otherDay: DateTime(2026, 11, 15));
    expect(FreeTimeRules.validate(day(), [d]).single.problem, DraftProblem.wrongDay);
  });

  test('server JSON maps to the same model', () {
    final d = PlanningDay.fromJson(DateTime(2026, 10, 29), {
      'windowStart': '07:00',
      'windowEnd': '22:00',
      'earliestStart': '15:43',
      'blocked': false,
      'busy': [
        {'start': '19:30', 'end': '22:00', 'kind': 'official', 'title': 'Evening routine', 'timeUnknown': true},
      ],
    });
    expect(d.busy.single.timeUnknown, isTrue);
    expect(d.freeSlots.map((s) => s.toString()), ['15:43–19:30']);
  });
}
