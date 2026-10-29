import 'package:flutter/material.dart';

import 'core/models/activity_category.dart';

/// Shared design tokens and themes for BOTH the participant and staff UIs.
///
/// Rule: screens never hardcode colours, spacing or radii – they use the
/// tokens below or `context.palette`. To change colours, edit this file only.

// ------------------------------------------------------------------ spacing

abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;

  /// Maximum width of the participant feed on tablets/desktop.
  static const double participantMaxWidth = 560;
}

/// Minimum interactive size for participant controls (above WCAG 44px).
const double kLargeTouchTarget = 56;

// ------------------------------------------------------------------- motion

abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration scrollToNow = Duration(milliseconds: 450);

  /// Returns [d], or zero when the platform or the participant profile asks
  /// for reduced motion (the participant shell sets disableAnimations).
  static Duration of(BuildContext context, [Duration d = standard]) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

// ------------------------------------------------------------------ palette

/// Semantic colours. Two variants: standard and high contrast.
@immutable
class PlannerPalette extends ThemeExtension<PlannerPalette> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color onBrand;
  final Color nowAccent;
  final Color doneSurface;
  final Color changeSurface;
  final Color changeBorder;
  final Color changeText;
  final Color success;
  final Color danger;
  final Color focus;

  const PlannerPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.onBrand,
    required this.nowAccent,
    required this.doneSurface,
    required this.changeSurface,
    required this.changeBorder,
    required this.changeText,
    required this.success,
    required this.danger,
    required this.focus,
  });

  static const standard = PlannerPalette(
    background: Color(0xFFF5F3EF), // existing warm oat background
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFECE6),
    border: Color(0xFFDDD8CF),
    textPrimary: Color(0xFF1F2933),
    textSecondary: Color(0xFF52606D),
    brand: Color(0xFF3F6E5A), // existing deep sage, darkened for contrast
    onBrand: Color(0xFFFFFFFF),
    nowAccent: Color(0xFF1F4E79),
    doneSurface: Color(0xFFF1F0EC),
    changeSurface: Color(0xFFFFF8E7), // existing calm update banner
    changeBorder: Color(0xFFE6C875),
    changeText: Color(0xFF744210),
    success: Color(0xFF2F855A),
    danger: Color(0xFFA63D32),
    focus: Color(0xFF1D4ED8),
  );

  static const highContrast = PlannerPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F0F0),
    border: Color(0xFF1A1A1A),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF1A1A1A),
    brand: Color(0xFF1B4332),
    onBrand: Color(0xFFFFFFFF),
    nowAccent: Color(0xFF0B2E59),
    doneSurface: Color(0xFFF2F2F2),
    changeSurface: Color(0xFFFFF3C4),
    changeBorder: Color(0xFF7A4B00),
    changeText: Color(0xFF3D2600),
    success: Color(0xFF1B5E20),
    danger: Color(0xFF8B1A10),
    focus: Color(0xFF0033CC),
  );

  @override
  PlannerPalette copyWith() => this;

  @override
  PlannerPalette lerp(ThemeExtension<PlannerPalette>? other, double t) =>
      t < 0.5 ? this : (other as PlannerPalette? ?? this);
}

extension PaletteContext on BuildContext {
  PlannerPalette get palette =>
      Theme.of(this).extension<PlannerPalette>() ?? PlannerPalette.standard;
}

// --------------------------------------------------------------- categories

/// Colour + icon + label per category, so colour is never the only cue.
///
/// Colours for work/meal/residential/personal are the mandatory TEACCH
/// colours from CLAUDE.md §5.
class CategoryStyle {
  final Color color;
  final IconData icon;
  final String label;

  const CategoryStyle(this.color, this.icon, this.label);

  static const _styles = {
    ActivityCategory.work:
        CategoryStyle(Color(0xFF2B6CB0), Icons.handyman_outlined, 'Training'),
    ActivityCategory.meal:
        CategoryStyle(Color(0xFFDD6B20), Icons.restaurant_outlined, 'Meal'),
    ActivityCategory.residential:
        CategoryStyle(Color(0xFF2F855A), Icons.home_outlined, 'Residence'),
    ActivityCategory.personal:
        CategoryStyle(Color(0xFF805AD5), Icons.person_outline, 'Personal'),
    ActivityCategory.travel: CategoryStyle(
        Color(0xFF4A5D73), Icons.directions_bus_outlined, 'Travel'),
    ActivityCategory.support: CategoryStyle(
        Color(0xFF9B4D6B), Icons.support_agent_outlined, 'Support'),
    ActivityCategory.freeTime:
        CategoryStyle(Color(0xFF3D7F86), Icons.spa_outlined, 'Free time'),
  };

  static CategoryStyle of(ActivityCategory c) => _styles[c]!;

  /// A soft tint of the category colour for large surfaces.
  Color get tint => color.withValues(alpha: 0.10);
}

// ------------------------------------------------------------------- themes

ThemeData buildPlannerTheme({bool highContrast = false}) {
  final palette =
      highContrast ? PlannerPalette.highContrast : PlannerPalette.standard;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.brand,
    primary: palette.brand,
    onPrimary: palette.onBrand,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    error: palette.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    extensions: [palette],
  );

  final text = base.textTheme.apply(
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );

  final borderSide = BorderSide(color: palette.border);
  final radius = BorderRadius.circular(AppRadius.md);

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    focusColor: palette.focus.withValues(alpha: 0.18),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: borderSide,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl, vertical: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xl, vertical: AppSpace.md),
        side: BorderSide(color: palette.border, width: 1.5),
        foregroundColor: palette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md + AppSpace.xxs),
      border: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      enabledBorder:
          OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.focus, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: borderSide,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    dividerTheme: DividerThemeData(color: palette.border, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.brand.withValues(alpha: 0.14),
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.brand.withValues(alpha: 0.14),
      selectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w700, color: palette.textPrimary),
      unselectedLabelTextStyle: TextStyle(color: palette.textSecondary),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
