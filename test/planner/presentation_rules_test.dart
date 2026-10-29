import 'package:bbw_visual_routine/core/data/mock_participants.dart';
import 'package:bbw_visual_routine/core/logic/presentation_rules.dart';
import 'package:bbw_visual_routine/core/models/participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one schedule is presented differently per participant profile', () {
    final lena = mockParticipants.firstWhere((p) => p.displayName == 'Lena');
    final jonas = mockParticipants.firstWhere((p) => p.displayName == 'Jonas');

    final minimal = CardPresentation.forProfile(lena.profile);
    expect(minimal.showPlace, isFalse);
    expect(minimal.showPerson, isFalse);
    expect(minimal.showWhatToBring, isFalse);
    expect(minimal.showPhoto, isFalse);
    expect(minimal.showSymbol, isTrue);
    expect(minimal.reducedMotion, isTrue);

    final detailed = CardPresentation.forProfile(jonas.profile);
    expect(detailed.showPlace, isTrue);
    expect(detailed.showPerson, isTrue);
    expect(detailed.showWhatToBring, isTrue);
    expect(detailed.showLeaveHint, isTrue);
    expect(detailed.transitionWarningMinutes, [5, 2, 1]);
  });

  test('time display preference controls bar and text', () {
    const p = ParticipantProfile();
    expect(
        CardPresentation.forProfile(p.copyWith(timeDisplay: TimeDisplay.progress))
            .showClockText,
        isFalse);
    expect(
        CardPresentation.forProfile(p.copyWith(timeDisplay: TimeDisplay.clock))
            .showProgressBar,
        isFalse);
  });
}
