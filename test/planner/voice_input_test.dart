import 'package:bbw_visual_routine/app/app_scope.dart';
import 'package:bbw_visual_routine/app/app_services.dart';
import 'package:bbw_visual_routine/core/time/clock.dart';
import 'package:bbw_visual_routine/screens_staff/ai/ai_event_builder_dialog.dart';
import 'package:bbw_visual_routine/services/speech_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the device recognizer; the test "speaks" via [say].
class FakeSpeech implements SpeechInput {
  SpeechUnavailable? problem;
  SpeechCallbacks? _cb;
  int starts = 0;
  bool cancelled = false;
  SpeechLanguage? startedWith;
  String _last = '';

  @override
  Future<SpeechUnavailable?> initialize() async => problem;

  @override
  bool get isListening => _cb != null;

  @override
  Future<void> start(SpeechLanguage language, SpeechCallbacks callbacks) async {
    starts++;
    startedWith = language;
    _cb = callbacks;
  }

  void say(String words) {
    _last = words;
    _cb!.onResult(words, false);
  }

  void fail(String message) {
    final cb = _cb!;
    _cb = null;
    cb.onError(message);
    cb.onDone();
  }

  @override
  Future<void> stop() async {
    final cb = _cb;
    _cb = null;
    cb?.onResult(_last, true);
    cb?.onDone();
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    _cb = null;
  }
}

void main() {
  late FakeSpeech speech;
  late AppServices services;

  setUp(() {
    speech = FakeSpeech();
    services = AppServices.demo(
      clock: DemoClock(startHour: 9, startMinute: 40, ticking: false),
      speech: speech,
    );
  });
  tearDown(() => services.dispose());

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showAiEventBuilder(context, day: DateTime(2026, 10, 29)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.widgetWithText(TextField, 'Describe the activities'))
      .controller!
      .text;

  FilledButton suggestButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
          of: find.text('Suggest activities'), matching: find.byType(FilledButton)));

  testWidgets('voice → existing text field → existing AI suggestions',
      (tester) async {
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pump();

    // Listening: indicator shown, phone language (English in tests),
    // generation blocked until dictation ends.
    expect(speech.starts, 1);
    expect(speech.startedWith, SpeechLanguage.english);
    expect(find.textContaining('Listening (EN)'), findsOneWidget);
    expect(suggestButton(tester).onPressed, isNull);

    // Live transcription replaces the example text.
    speech.say('Tomorrow woodworking');
    await tester.pump();
    expect(fieldText(tester), 'Tomorrow woodworking');
    speech.say('Tomorrow woodworking at 9 and lunch at 12');
    await tester.pump();

    // Tap again → stop.
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pump();
    expect(find.textContaining('Listening'), findsNothing);
    expect(fieldText(tester), 'Tomorrow woodworking at 9 and lunch at 12');

    // Staff corrects the text, then uses the unchanged generate button.
    await tester.enterText(find.widgetWithText(TextField, 'Describe the activities'),
        'Tomorrow woodworking at 9 and lunch at 12:30');
    await tester.tap(find.text('Suggest activities'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Review suggestions'), findsOneWidget);
    expect(find.textContaining('12:30'), findsWidgets);
  });

  testWidgets('dictation is appended to text the user already typed',
      (tester) async {
    await openDialog(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Describe the activities'), 'Lunch at 12,');
    await tester.tap(find.text('DE'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pump();
    expect(speech.startedWith, SpeechLanguage.german, reason: 'user choice wins');
    expect(find.textContaining('Listening (DE)'), findsOneWidget);
    speech.say('physiotherapy at 2');
    await tester.pump();
    expect(fieldText(tester), 'Lunch at 12, physiotherapy at 2');
  });

  testWidgets('denied microphone permission shows a message, never listens',
      (tester) async {
    speech.problem = SpeechUnavailable.permissionDenied;
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pumpAndSettle();
    expect(speech.starts, 0);
    expect(find.textContaining('Microphone access was denied'), findsOneWidget);
    expect(suggestButton(tester).onPressed, isNotNull, reason: 'typing still works');
  });

  testWidgets('unsupported device shows a message', (tester) async {
    speech.problem = SpeechUnavailable.notSupported;
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not available on this device'), findsOneWidget);
  });

  testWidgets('recognition error ends listening and keeps the text editable',
      (tester) async {
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pump();
    speech.fail(DeviceSpeechInput.describe('error_no_match'));
    await tester.pump();
    expect(find.textContaining("didn't catch anything"), findsOneWidget);
    expect(find.textContaining('Listening'), findsNothing);
    expect(suggestButton(tester).onPressed, isNotNull);
  });

  testWidgets('closing the dialog while listening cancels recognition',
      (tester) async {
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('voice-input')));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(speech.cancelled, isTrue);
  });

  test('default language follows the phone language', () {
    expect(SpeechLanguage.forLocale(const Locale('de', 'DE')), SpeechLanguage.german);
    expect(SpeechLanguage.forLocale(const Locale('en', 'US')), SpeechLanguage.english);
    expect(SpeechLanguage.forLocale(const Locale('fr')), SpeechLanguage.english);
  });

  test('platform error codes map to clear messages', () {
    expect(DeviceSpeechInput.describe('error_speech_timeout'), contains("didn't catch"));
    expect(DeviceSpeechInput.describe('error_permission'), contains('Microphone'));
    expect(DeviceSpeechInput.describe('error_network'), contains('not reachable'));
    expect(DeviceSpeechInput.describe('error_language_unavailable'),
        contains('language'));
    expect(DeviceSpeechInput.describe('error_busy'), contains('busy'));
    expect(DeviceSpeechInput.describe('weird'), contains('try again'));
  });
}
