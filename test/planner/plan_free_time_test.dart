import 'package:bbw_visual_routine/app/app_scope.dart';
import 'package:bbw_visual_routine/app/app_services.dart';
import 'package:bbw_visual_routine/core/logic/free_time.dart';
import 'package:bbw_visual_routine/core/planning/free_time_planner.dart';
import 'package:bbw_visual_routine/core/time/clock.dart';
import 'package:bbw_visual_routine/screens_participant/plan/plan_free_time_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_input_test.dart' show FakeSpeech;

class FakePlanner implements FreeTimeBackend {
  PlanningDay day;
  List<DraftActivity> suggestion = const [];
  String? lastText;
  List<DraftActivity>? saved;
  PlanSaveException? saveError;

  FakePlanner(this.day);

  @override
  Future<PlanningDay> loadDay(DateTime date) async => day;

  @override
  Future<List<DraftActivity>> suggest(String text, PlanningDay day) async {
    lastText = text;
    return suggestion;
  }

  @override
  Future<void> save(PlanningDay day, List<DraftActivity> drafts) async {
    if (saveError != null) throw saveError!;
    saved = drafts;
  }
}

PlanningDay saturday({List<BusyPeriod> busy = const [], bool blocked = false}) => PlanningDay(
      date: DateTime(2026, 11, 14),
      windowStart: parseHm('07:00'),
      windowEnd: parseHm('22:00'),
      earliestStart: parseHm('07:00'),
      blocked: blocked,
      blockedReason: blocked ? 'An activity on this day has no time yet ("Trip"). Please ask staff.' : null,
      busy: busy,
    );

void main() {
  late FakeSpeech speech;
  late FakePlanner planner;
  late AppServices services;

  Future<void> open(WidgetTester tester, {int? slotStart}) async {
    services = AppServices.demo(
      clock: DemoClock(startHour: 9, startMinute: 40, ticking: false),
      speech: speech,
      freeTime: planner,
    );
    addTearDown(services.dispose);
    tester.view.physicalSize = const Size(700, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFreeTimePlanner(context,
                  date: DateTime(2026, 11, 14),
                  slotStart: slotStart == null ? null : DateTime(2026, 11, 14, slotStart ~/ 60, slotStart % 60)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    speech = FakeSpeech();
    planner = FakePlanner(saturday());
  });

  testWidgets('empty Saturday: speak → edit → AI draft → choose length → save', (tester) async {
    planner.suggestion = [
      DraftActivity(title: 'Breakfast', start: parseHm('08:00')), // no length given
      DraftActivity(title: 'Football', start: parseHm('14:00'), end: parseHm('15:30')),
    ];
    await open(tester);
    expect(find.text('07:00–22:00'), findsOneWidget, reason: 'whole window is free');

    await tester.tap(find.byKey(const Key('dictation')));
    await tester.pump();
    expect(find.textContaining('Listening'), findsOneWidget);
    speech.say('breakfast at 8 and football at 2 pm');
    await tester.pump();
    await tester.tap(find.byKey(const Key('dictation'))); // stop
    await tester.pump();

    // Transcript is editable and NOT sent automatically.
    expect(planner.lastText, isNull);
    await tester.enterText(find.byType(TextField).first,
        'breakfast at 8 and football from 2 pm until 3:30 pm');
    await tester.tap(find.text('Make a plan'));
    await tester.pumpAndSettle();
    expect(planner.lastText, 'breakfast at 8 and football from 2 pm until 3:30 pm');

    // Breakfast has no length: participant must choose, nothing invented.
    expect(find.textContaining('How long does it take'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('save-plan'))).onPressed, isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, '30 min').first);
    await tester.pumpAndSettle();
    expect(find.text('Fits in your free time.'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('save-plan')));
    await tester.pumpAndSettle();
    expect(find.text('Save my plan?'), findsOneWidget, reason: 'explicit confirmation');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(planner.saved!.map((d) => '${d.title} ${formatHm(d.start!)}-${formatHm(d.end!)}'),
        ['Breakfast 08:00-08:30', 'Football 14:00-15:30']);
    expect(find.textContaining('Your plan is saved'), findsOneWidget);
  });

  testWidgets('official activities are read-only and block their time', (tester) async {
    planner.day = saturday(busy: [
      const BusyPeriod(start: 660, end: 720, kind: BusyKind.official, title: 'Sports club'),
    ]);
    planner.suggestion = [DraftActivity(title: 'Football', start: parseHm('11:00'), end: parseHm('12:00'))];
    await open(tester);
    expect(find.text('07:00–11:00'), findsOneWidget);
    expect(find.text('12:00–22:00'), findsOneWidget);
    expect(find.text('Sports club'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'football at 11');
    await tester.pump();
    await tester.tap(find.text('Make a plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('taken by "Sports club"'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('save-plan'))).onPressed, isNull);
  });

  testWidgets('tapping a free slot preselects it for "Add one myself"', (tester) async {
    await open(tester, slotStart: parseHm('15:00'));
    await tester.tap(find.text('Add one myself'));
    await tester.pumpAndSettle();
    expect(find.text('Starts 07:00'), findsOneWidget, reason: 'slot 07:00–22:00 contains 15:00');
  });

  testWidgets('a day staff must clarify cannot be planned', (tester) async {
    planner.day = saturday(blocked: true);
    await open(tester);
    expect(find.text('This day cannot be planned yet.'), findsOneWidget);
    expect(find.textContaining('Please ask staff'), findsOneWidget);
    expect(find.text('Make a plan'), findsNothing);
    expect(find.byKey(const Key('dictation')), findsNothing);
  });

  testWidgets('a server conflict saves nothing and marks the activity', (tester) async {
    planner.suggestion = [DraftActivity(title: 'Shopping', start: parseHm('10:00'), end: parseHm('11:00'))];
    planner.saveError = const PlanSaveException(
        'Something changed in the meantime. Nothing was saved; please check the marked times.',
        {0: 'Now taken by "Trip". Choose another time.'});
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'shopping at 10');
    await tester.pump();
    await tester.tap(find.text('Make a plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Now taken by "Trip"'), findsOneWidget);
    expect(find.text('Plan my free time'), findsOneWidget, reason: 'still on the page');
  });
}
