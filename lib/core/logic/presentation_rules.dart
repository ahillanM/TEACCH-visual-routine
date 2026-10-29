import '../models/participant.dart';

/// Which elements a participant card shows, derived from the profile.
///
/// Cards never read the profile directly; they ask this object. To change
/// what "minimal" or "detailed" means, edit only [CardPresentation.forProfile].
class CardPresentation {
  final bool showPhoto;
  final bool showSymbol;
  final bool showPlace;
  final bool showPerson;
  final bool showWhatToBring;
  final bool showInstructionsPreview;
  final bool showLeaveHint;
  final bool showProgressBar;
  final bool showClockText;
  final List<int> transitionWarningMinutes;
  final bool reducedMotion;

  const CardPresentation({
    required this.showPhoto,
    required this.showSymbol,
    required this.showPlace,
    required this.showPerson,
    required this.showWhatToBring,
    required this.showInstructionsPreview,
    required this.showLeaveHint,
    required this.showProgressBar,
    required this.showClockText,
    required this.transitionWarningMinutes,
    required this.reducedMotion,
  });

  /// Minutes before a travel-dependent activity at which to suggest leaving.
  static const int leaveEarlyMinutes = 10;

  factory CardPresentation.forProfile(ParticipantProfile p) {
    final density = p.informationDensity;
    return CardPresentation(
      showPhoto: p.visualPreference != VisualPreference.symbols,
      showSymbol: p.visualPreference != VisualPreference.photos,
      showPlace: density != InformationDensity.minimal,
      showPerson: density != InformationDensity.minimal,
      showWhatToBring: density == InformationDensity.detailed,
      showInstructionsPreview: density == InformationDensity.detailed,
      showLeaveHint: density == InformationDensity.detailed,
      showProgressBar: p.timeDisplay != TimeDisplay.clock,
      showClockText: p.timeDisplay != TimeDisplay.progress,
      transitionWarningMinutes: p.transitionWarning.minutesBefore,
      reducedMotion: p.motion == MotionPreference.reduced,
    );
  }
}
