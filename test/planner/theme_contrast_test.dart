import 'dart:math' as math;

import 'package:bbw_visual_routine/core/models/task_color.dart';
import 'package:bbw_visual_routine/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const normalText = 4.5;

  for (final (name, p) in [
    ('light', PlannerPalette.standard),
    ('high contrast', PlannerPalette.highContrast),
    ('dark', PlannerPalette.dark),
  ]) {
    group('$name palette meets WCAG AA', () {
      test('body text', () {
        for (final bg in [p.background, p.surface, p.surfaceElevated]) {
          expect(
            _contrast(p.textPrimary, bg),
            greaterThanOrEqualTo(normalText),
          );
          expect(
            _contrast(p.textSecondary, bg),
            greaterThanOrEqualTo(normalText),
          );
        }
      });

      test('primary buttons and sidebar', () {
        expect(_contrast(p.onBrand, p.brand), greaterThanOrEqualTo(normalText));
        expect(
          _contrast(p.onSidebar, p.sidebar),
          greaterThanOrEqualTo(normalText),
        );
        expect(
          _contrast(p.onSidebarActive, p.sidebarActive),
          greaterThanOrEqualTo(normalText),
        );
      });

      test('semantic tones on surface and on their soft background', () {
        for (final tone in [
          p.work,
          p.support,
          p.travel,
          p.residential,
          p.freeTime,
          p.change,
        ]) {
          expect(
            _contrast(tone.color, p.surface),
            greaterThanOrEqualTo(normalText),
          );
          expect(
            _contrast(tone.color, tone.soft),
            greaterThanOrEqualTo(normalText),
          );
          expect(
            _contrast(p.onColor(tone.color), tone.color),
            greaterThanOrEqualTo(normalText),
          );
        }
        expect(
          _contrast(p.danger, p.surface),
          greaterThanOrEqualTo(normalText),
        );
      });

      test('task colours', () {
        for (final c in TaskColor.values) {
          final tone = TaskColorStyle.of(c, p);
          expect(
            _contrast(tone.color, p.surface),
            greaterThanOrEqualTo(normalText),
            reason: c.label,
          );
          expect(
            _contrast(tone.color, tone.soft),
            greaterThanOrEqualTo(normalText),
            reason: c.label,
          );
        }
      });
    });
  }
}
