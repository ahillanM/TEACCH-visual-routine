import 'package:flutter/material.dart';

import '../../core/models/participant.dart';
import '../../theme.dart';

/// Edits a [ParticipantProfile]. Changes apply immediately to the
/// participant's cards (and to "Preview as participant").
class ProfilePreferencesEditor extends StatelessWidget {
  final ParticipantProfile profile;
  final ValueChanged<ParticipantProfile> onChanged;

  const ProfilePreferencesEditor({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Choice<InformationDensity>(
          label: 'Information density',
          value: profile.informationDensity,
          options: const {
            InformationDensity.minimal: 'Minimal',
            InformationDensity.standard: 'Standard',
            InformationDensity.detailed: 'Detailed',
          },
          onChanged: (v) => onChanged(profile.copyWith(informationDensity: v)),
        ),
        _Choice<VisualPreference>(
          label: 'Visuals',
          value: profile.visualPreference,
          options: const {
            VisualPreference.photos: 'Photos',
            VisualPreference.symbols: 'Symbols',
            VisualPreference.both: 'Both',
          },
          onChanged: (v) => onChanged(profile.copyWith(visualPreference: v)),
        ),
        _Choice<TransitionWarning>(
          label: 'Transition warnings',
          value: profile.transitionWarning,
          options: const {
            TransitionWarning.none: 'None',
            TransitionWarning.fiveMinutes: '5 min',
            TransitionWarning.fiveTwoOne: '5 / 2 / 1 min',
          },
          onChanged: (v) => onChanged(profile.copyWith(transitionWarning: v)),
        ),
        _Choice<TimeDisplay>(
          label: 'Time display',
          value: profile.timeDisplay,
          options: const {
            TimeDisplay.progress: 'Progress bar',
            TimeDisplay.clock: 'Text',
            TimeDisplay.both: 'Both',
          },
          onChanged: (v) => onChanged(profile.copyWith(timeDisplay: v)),
        ),
        _Choice<TextSizePreference>(
          label: 'Text size',
          value: profile.textSize,
          options: const {
            TextSizePreference.standard: 'Standard',
            TextSizePreference.large: 'Large',
          },
          onChanged: (v) => onChanged(profile.copyWith(textSize: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('High contrast'),
          value: profile.highContrast,
          onChanged: (v) => onChanged(profile.copyWith(highContrast: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reduced motion'),
          value: profile.motion == MotionPreference.reduced,
          onChanged: (v) => onChanged(profile.copyWith(
              motion: v ? MotionPreference.reduced : MotionPreference.standard)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound for reminders'),
          subtitle: const Text('Stored preference (not played in prototype)'),
          value: profile.soundEnabled,
          onChanged: (v) => onChanged(profile.copyWith(soundEnabled: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibration for reminders'),
          subtitle: const Text('Stored preference (not triggered in prototype)'),
          value: profile.vibrationEnabled,
          onChanged: (v) => onChanged(profile.copyWith(vibrationEnabled: v)),
        ),
      ],
    );
  }
}

class _Choice<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpace.xs),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final e in options.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}
