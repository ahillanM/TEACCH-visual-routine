/// How much information a participant sees on each card.
enum InformationDensity { minimal, standard, detailed }

/// Which visuals a participant prefers on cards.
enum VisualPreference { photos, symbols, both }

/// Gentle transition warnings before an activity ends.
enum TransitionWarning {
  none([]),
  fiveMinutes([5]),
  fiveTwoOne([5, 2, 1]);

  /// Minutes before the end of an activity at which a warning is shown.
  final List<int> minutesBefore;
  const TransitionWarning(this.minutesBefore);
}

/// How the passing of time is shown on the current card.
enum TimeDisplay { progress, clock, both }

enum MotionPreference { reduced, standard }

enum TextSizePreference { standard, large }

/// Support and presentation preferences for one participant.
///
/// The participant UI reads these through `CardPresentation`; staff edit them
/// on the participant detail page. One underlying schedule is rendered
/// differently according to this profile.
class ParticipantProfile {
  final InformationDensity informationDensity;
  final VisualPreference visualPreference;
  final TransitionWarning transitionWarning;
  final TimeDisplay timeDisplay;
  final MotionPreference motion;
  final bool soundEnabled;

  /// Stored as a preference only; the prototype does not trigger haptics.
  final bool vibrationEnabled;
  final bool highContrast;
  final TextSizePreference textSize;

  const ParticipantProfile({
    this.informationDensity = InformationDensity.standard,
    this.visualPreference = VisualPreference.both,
    this.transitionWarning = TransitionWarning.fiveMinutes,
    this.timeDisplay = TimeDisplay.both,
    this.motion = MotionPreference.standard,
    this.soundEnabled = false,
    this.vibrationEnabled = false,
    this.highContrast = false,
    this.textSize = TextSizePreference.standard,
  });

  ParticipantProfile copyWith({
    InformationDensity? informationDensity,
    VisualPreference? visualPreference,
    TransitionWarning? transitionWarning,
    TimeDisplay? timeDisplay,
    MotionPreference? motion,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? highContrast,
    TextSizePreference? textSize,
  }) {
    return ParticipantProfile(
      informationDensity: informationDensity ?? this.informationDensity,
      visualPreference: visualPreference ?? this.visualPreference,
      transitionWarning: transitionWarning ?? this.transitionWarning,
      timeDisplay: timeDisplay ?? this.timeDisplay,
      motion: motion ?? this.motion,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      highContrast: highContrast ?? this.highContrast,
      textSize: textSize ?? this.textSize,
    );
  }
}

/// A fictional participant. Only a first name is stored in the prototype
/// (data minimisation).
class Participant {
  final String id;
  final String displayName;
  final String livingGroup;
  final ParticipantProfile profile;

  /// Mock "familiarity" data used by the impact checker to flag places a
  /// participant has not been to before. Not a clinical measure.
  final Set<String> familiarPlaceIds;

  const Participant({
    required this.id,
    required this.displayName,
    required this.livingGroup,
    this.profile = const ParticipantProfile(),
    this.familiarPlaceIds = const {},
  });

  String get initials => displayName.isEmpty ? '?' : displayName[0];

  Participant copyWith({ParticipantProfile? profile}) {
    return Participant(
      id: id,
      displayName: displayName,
      livingGroup: livingGroup,
      profile: profile ?? this.profile,
      familiarPlaceIds: familiarPlaceIds,
    );
  }
}
