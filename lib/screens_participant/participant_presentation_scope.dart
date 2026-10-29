import 'package:flutter/material.dart';

import '../core/logic/presentation_rules.dart';
import '../core/models/participant.dart';
import '../theme.dart';

/// Applies a participant's profile to everything below it:
/// high-contrast theme, larger text, reduced motion, and the
/// [CardPresentation] rules cards read via [ParticipantPresentationScope.of].
///
/// Used by the real participant UI AND by staff "Preview as participant",
/// so both always render identically.
class ParticipantPresentationScope extends StatelessWidget {
  final ParticipantProfile profile;
  final Widget child;

  const ParticipantPresentationScope({
    super.key,
    required this.profile,
    required this.child,
  });

  static const double largeTextScale = 1.25;

  static CardPresentation of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PresentationInherited>();
    return scope?.presentation ??
        CardPresentation.forProfile(const ParticipantProfile());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final presentation = CardPresentation.forProfile(profile);
    final scale = profile.textSize == TextSizePreference.large
        ? largeTextScale
        : 1.0;

    return Theme(
      data: buildPlannerTheme(highContrast: profile.highContrast),
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
          disableAnimations:
              media.disableAnimations || presentation.reducedMotion,
        ),
        child: _PresentationInherited(
          presentation: presentation,
          child: child,
        ),
      ),
    );
  }
}

class _PresentationInherited extends InheritedWidget {
  final CardPresentation presentation;

  const _PresentationInherited({
    required this.presentation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PresentationInherited old) =>
      old.presentation != presentation;
}
