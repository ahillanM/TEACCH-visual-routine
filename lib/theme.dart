import 'package:flutter/material.dart';

import 'core/models/activity_category.dart';
import 'core/models/task_color.dart';

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

  /// Buttons and inputs.
  static const double control = 12;
  static const double md = 16;

  /// Staff cards.
  static const double card = 18;

  /// Participant task cards, dialogs.
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

/// One semantic hue in the three strengths the UI needs.
///
/// * [color]  – text-safe tone for labels, icons, badges, strips and
///              progress (>= 4.5:1 on surface and on [soft]).
/// * [accent] – the pure "Groovy Calm" hue for decorative fills and markers.
/// * [soft]   – quiet tinted background.
@immutable
class SemanticTone {
  final Color color;
  final Color accent;
  final Color soft;

  const SemanticTone({
    required this.color,
    required this.accent,
    required this.soft,
  });
}

/// "Groovy Calm" semantic colours. Variants: [standard] (light),
/// [highContrast] (participant option) and [dark] (staff only).
///
/// Meaning is the same everywhere: petrol = work / primary, lavender =
/// support, apricot = travel / transition, mustard = change / attention,
/// dusty blue = residential / personal / info, sage = free time / breaks.
/// Red ([danger]) is reserved for genuine errors – never schedule changes.
@immutable
class PlannerPalette extends ThemeExtension<PlannerPalette> {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color nowAccent;
  final Color doneSurface;
  final Color success;
  final Color danger;
  final Color dangerSoft;
  final Color focus;

  /// Staff sidebar – the main visual anchor of the staff UI.
  final Color sidebar;
  final Color onSidebar;
  final Color sidebarActive;
  final Color onSidebarActive;

  /// Frame drawn around the staff "preview as participant" phone.
  final Color previewFrame;

  final SemanticTone work;
  final SemanticTone support;
  final SemanticTone travel;
  final SemanticTone residential;
  final SemanticTone freeTime;
  final SemanticTone change;

  const PlannerPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.nowAccent,
    required this.doneSurface,
    required this.success,
    required this.danger,
    required this.dangerSoft,
    required this.focus,
    required this.sidebar,
    required this.onSidebar,
    required this.sidebarActive,
    required this.onSidebarActive,
    required this.previewFrame,
    required this.work,
    required this.support,
    required this.travel,
    required this.residential,
    required this.freeTime,
    required this.change,
  });

  bool get isDark => brightness == Brightness.dark;

  // Semantic aliases (primary / secondary / accent / attention / info).
  Color get secondary => support.color;
  Color get secondarySoft => support.soft;
  Color get accent => travel.color;
  Color get accentSoft => travel.soft;
  Color get attention => change.color;
  Color get attentionSoft => change.soft;
  Color get info => residential.color;
  Color get infoSoft => residential.soft;

  // Change / needs-attention treatment (mustard + butter cream, never red).
  Color get changeSurface => change.soft;
  Color get changeBorder => change.accent;
  Color get changeText => change.color;

  /// Scheduling conflicts are planning problems, not system errors.
  Color get conflict => travel.color;

  /// Light palette. WCAG contrast of text tones is noted per value.
  static const standard = PlannerPalette(
    brightness: Brightness.light,
    background: Color(0xFFF7F5EF), // warm cream
    surface: Color(0xFFFFFEFB), // soft white
    surfaceElevated: Color(0xFFFFFEFB),
    surfaceMuted: Color(0xFFEFEDE6),
    border: Color(0xFFD9D8D2), // warm grey
    textPrimary: Color(0xFF202A2E), // ink
    textSecondary: Color(0xFF58656A), // slate – 5.5:1 cream, 4.8:1 sage
    brand: Color(0xFF195C55), // deep petrol – 7.1:1 on cream
    brandSoft: Color(0xFFD8EAE4), // sage mint
    onBrand: Color(0xFFFFFFFF), // 7.8:1 on petrol
    nowAccent: Color(0xFF195C55),
    doneSurface: Color(0xFFF2F0EA),
    success: Color(0xFF4B6B3C),
    danger: Color(0xFF9E3B34), // muted red – 6.7:1 on surface
    dangerSoft: Color(0xFFF6E2DF),
    focus: Color(0xFF36657F),
    sidebar: Color(0xFF123F3B),
    onSidebar: Color(0xFFE8F1EC), // 10.1:1 on sidebar
    sidebarActive: Color(0xFFD8EAE4),
    onSidebarActive: Color(0xFF195C55), // 6.2:1 on sage mint
    previewFrame: Color(0xFF202A2E),
    work: SemanticTone(
      color: Color(0xFF195C55),
      accent: Color(0xFF195C55),
      soft: Color(0xFFDDE8EB),
    ),
    // Lavender #7566A8 is 4.0:1 on lavender mist, so text uses a deeper tone.
    support: SemanticTone(
      color: Color(0xFF5E4F94), // 5.6:1 on mist
      accent: Color(0xFF7566A8),
      soft: Color(0xFFE9E5F4),
    ),
    // Apricot #D97952 is 2.5:1 on peach – text uses burnt apricot.
    travel: SemanticTone(
      color: Color(0xFF9A4A28), // 4.9:1 on peach
      accent: Color(0xFFD97952),
      soft: Color(0xFFF8E1D5),
    ),
    // Dusty blue #497E9D is 3.6:1 on mist blue – text uses a deeper tone.
    residential: SemanticTone(
      color: Color(0xFF36657F), // 5.1:1 on mist blue
      accent: Color(0xFF497E9D),
      soft: Color(0xFFDCEAF1),
    ),
    freeTime: SemanticTone(
      color: Color(0xFF4B6B3C), // olive sage – 4.9:1 on sage mint
      accent: Color(0xFF8DBFAC),
      soft: Color(0xFFD8EAE4),
    ),
    // Mustard #D5A62E is 1.9:1 on butter cream – text uses deep mustard.
    change: SemanticTone(
      color: Color(0xFF735600), // 5.9:1 on butter cream
      accent: Color(0xFFD5A62E),
      soft: Color(0xFFF8EDC7),
    ),
  );

  /// Participant high-contrast option: same hues, stronger borders and text.
  static const highContrast = PlannerPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F0EC),
    border: Color(0xFF202A2E),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF202A2E),
    brand: Color(0xFF0E403B),
    brandSoft: Color(0xFFD8EAE4),
    onBrand: Color(0xFFFFFFFF),
    nowAccent: Color(0xFF0E403B),
    doneSurface: Color(0xFFF2F2EE),
    success: Color(0xFF244A34),
    danger: Color(0xFF7E2620),
    dangerSoft: Color(0xFFF6E2DF),
    focus: Color(0xFF1F4A61),
    sidebar: Color(0xFF0E403B),
    onSidebar: Color(0xFFFFFFFF),
    sidebarActive: Color(0xFFD8EAE4),
    onSidebarActive: Color(0xFF0E403B),
    previewFrame: Color(0xFF000000),
    work: SemanticTone(
      color: Color(0xFF0E403B),
      accent: Color(0xFF195C55),
      soft: Color(0xFFD8EAE4),
    ),
    support: SemanticTone(
      color: Color(0xFF45397A),
      accent: Color(0xFF7566A8),
      soft: Color(0xFFE9E5F4),
    ),
    travel: SemanticTone(
      color: Color(0xFF7A3518),
      accent: Color(0xFFD97952),
      soft: Color(0xFFF8E1D5),
    ),
    residential: SemanticTone(
      color: Color(0xFF244E66),
      accent: Color(0xFF497E9D),
      soft: Color(0xFFDCEAF1),
    ),
    freeTime: SemanticTone(
      color: Color(0xFF244A34),
      accent: Color(0xFF8DBFAC),
      soft: Color(0xFFD8EAE4),
    ),
    change: SemanticTone(
      color: Color(0xFF4F3B00),
      accent: Color(0xFF8A6500),
      soft: Color(0xFFF8EDC7),
    ),
  );

  /// Staff dark mode: deep forest / petrol, never pure black.
  static const dark = PlannerPalette(
    brightness: Brightness.dark,
    background: Color(0xFF101817),
    surface: Color(0xFF182321),
    surfaceElevated: Color(0xFF202D2A),
    surfaceMuted: Color(0xFF202D2A),
    border: Color(0xFF34423F),
    textPrimary: Color(0xFFF2F5F2), // 16.4:1 on background
    textSecondary: Color(0xFFB9C4C0), // 9.0:1 surface, 8.0:1 elevated
    brand: Color(0xFF65B8A9), // 6.9:1 on surface
    brandSoft: Color(0xFF263E39),
    onBrand: Color(0xFF101817), // 7.7:1 on petrol accent
    nowAccent: Color(0xFF65B8A9),
    doneSurface: Color(0xFF141E1C),
    success: Color(0xFFB5D69A),
    danger: Color(0xFFE8918A), // 6.8:1 on surface
    dangerSoft: Color(0xFF3D3734),
    focus: Color(0xFF7DB2CF),
    sidebar: Color(0xFF0A2421),
    onSidebar: Color(0xFFDCE6E2),
    sidebarActive: Color(0xFF65B8A9),
    onSidebarActive: Color(0xFF101817),
    previewFrame: Color(0xFF34423F),
    // Soft tones are the accent at 18% over surface; accents stay >= 4.6:1.
    work: SemanticTone(
      color: Color(0xFF65B8A9),
      accent: Color(0xFF65B8A9),
      soft: Color(0xFF263E39),
    ),
    support: SemanticTone(
      color: Color(0xFFA99AD7),
      accent: Color(0xFFA99AD7),
      soft: Color(0xFF323842),
    ),
    travel: SemanticTone(
      color: Color(0xFFEE9A76),
      accent: Color(0xFFEE9A76),
      soft: Color(0xFF3F3830),
    ),
    residential: SemanticTone(
      color: Color(0xFF7DB2CF),
      accent: Color(0xFF7DB2CF),
      soft: Color(0xFF2A3D40),
    ),
    freeTime: SemanticTone(
      color: Color(0xFFB5D69A),
      accent: Color(0xFFB5D69A),
      soft: Color(0xFF344337),
    ),
    change: SemanticTone(
      color: Color(0xFFE6C45A),
      accent: Color(0xFFE6C45A),
      soft: Color(0xFF3D402B),
    ),
  );

  /// Readable text/icon colour on top of a filled [background].
  Color onColor(Color background) => background.computeLuminance() > 0.18
      ? const Color(0xFF101817)
      : const Color(0xFFFFFFFF);

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
/// Colours follow the "Groovy Calm" semantics of [PlannerPalette]. Pass the
/// current palette (`context.palette`) so staff dark mode gets its tones.
class CategoryStyle {
  final SemanticTone tone;
  final IconData icon;
  final String label;

  const CategoryStyle(this.tone, this.icon, this.label);

  /// Text-safe category colour (labels, icons, badges, strips, progress).
  Color get color => tone.color;

  /// Soft category background for large surfaces.
  Color get tint => tone.soft;

  static CategoryStyle of(
    ActivityCategory c, [
    PlannerPalette palette = PlannerPalette.standard,
  ]) => switch (c) {
    ActivityCategory.work => CategoryStyle(
      palette.work,
      Icons.handyman_outlined,
      'Training',
    ),
    ActivityCategory.meal => CategoryStyle(
      palette.freeTime,
      Icons.restaurant_outlined,
      'Meal',
    ),
    ActivityCategory.residential => CategoryStyle(
      palette.residential,
      Icons.home_outlined,
      'Residence',
    ),
    ActivityCategory.personal => CategoryStyle(
      palette.residential,
      Icons.person_outline,
      'Personal',
    ),
    ActivityCategory.travel => CategoryStyle(
      palette.travel,
      Icons.directions_bus_outlined,
      'Travel',
    ),
    ActivityCategory.support => CategoryStyle(
      palette.support,
      Icons.support_agent_outlined,
      'Support',
    ),
    ActivityCategory.freeTime => CategoryStyle(
      palette.freeTime,
      Icons.spa_outlined,
      'Free Time',
    ),
  };
}

/// Tones for the colours staff give to tasks ([TaskColor]). Five reuse the
/// palette hues; rose, sand and slate are extra so there are enough choices.
abstract final class TaskColorStyle {
  static const _roseLight = SemanticTone(
    color: Color(0xFF94405E), // 5.4:1 on its soft tone
    accent: Color(0xFFC4708F),
    soft: Color(0xFFF6E1E9),
  );
  static const _sandLight = SemanticTone(
    color: Color(0xFF7A5A36), // 5.1:1 on its soft tone
    accent: Color(0xFFB8925F),
    soft: Color(0xFFF0E5D6),
  );
  static const _slateLight = SemanticTone(
    color: Color(0xFF4E5D66), // 5.6:1 on its soft tone
    accent: Color(0xFF7D8D96),
    soft: Color(0xFFE4E9EB),
  );
  static const _roseDark = SemanticTone(
    color: Color(0xFFE79BB7),
    accent: Color(0xFFE79BB7),
    soft: Color(0xFF3D393C),
  );
  static const _sandDark = SemanticTone(
    color: Color(0xFFD9B88E),
    accent: Color(0xFFD9B88E),
    soft: Color(0xFF3B3E35),
  );
  static const _slateDark = SemanticTone(
    color: Color(0xFFAEBDC5),
    accent: Color(0xFFAEBDC5),
    soft: Color(0xFF333F3F),
  );

  static SemanticTone of(
    TaskColor c, [
    PlannerPalette palette = PlannerPalette.standard,
  ]) =>
      switch (c) {
        TaskColor.petrol => palette.work,
        TaskColor.blue => palette.residential,
        TaskColor.lavender => palette.support,
        TaskColor.apricot => palette.travel,
        TaskColor.sage => palette.freeTime,
        TaskColor.rose => palette.isDark ? _roseDark : _roseLight,
        TaskColor.sand => palette.isDark ? _sandDark : _sandLight,
        TaskColor.slate => palette.isDark ? _slateDark : _slateLight,
      };
}

// ------------------------------------------------------------------- themes

/// [dark] is only used by the staff interface; participants are always light.
ThemeData buildPlannerTheme({bool highContrast = false, bool dark = false}) {
  final palette = dark
      ? PlannerPalette.dark
      : highContrast
      ? PlannerPalette.highContrast
      : PlannerPalette.standard;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.brand,
    brightness: palette.brightness,
    primary: palette.brand,
    onPrimary: palette.onBrand,
    primaryContainer: palette.brandSoft,
    onPrimaryContainer: palette.textPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onColor(palette.secondary),
    secondaryContainer: palette.brandSoft,
    onSecondaryContainer: palette.textPrimary,
    tertiary: palette.accent,
    onTertiary: palette.onColor(palette.accent),
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    surfaceContainerLowest: palette.surface,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surfaceElevated,
    surfaceContainerHigh: palette.surfaceElevated,
    surfaceContainerHighest: palette.surfaceMuted,
    outline: palette.textSecondary,
    outlineVariant: palette.border,
    error: palette.danger,
    onError: palette.onColor(palette.danger),
    errorContainer: palette.dangerSoft,
    onErrorContainer: palette.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    extensions: [palette],
  );

  final text = base.textTheme.apply(
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );

  final borderSide = BorderSide(color: palette.border);
  final radius = BorderRadius.circular(AppRadius.control);

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    focusColor: palette.focus.withValues(alpha: 0.18),
    hoverColor: palette.brand.withValues(alpha: 0.06),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: borderSide,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surfaceElevated,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surfaceElevated,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.md,
        ),
        side: BorderSide(color: palette.border, width: 1.5),
        foregroundColor: palette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        foregroundColor: palette.brand,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md + AppSpace.xxs,
      ),
      border: OutlineInputBorder(borderRadius: radius, borderSide: borderSide),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.focus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: palette.danger, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: borderSide,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.isDark
          ? palette.surfaceElevated
          : palette.textPrimary,
      contentTextStyle: TextStyle(
        color: palette.isDark ? palette.textPrimary : palette.background,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.brandSoft,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.brand
              : palette.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
    ),
    // Only the staff UI uses the rail / drawer: dark petrol sidebar.
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.sidebar,
      indicatorColor: palette.sidebarActive,
      selectedIconTheme: IconThemeData(color: palette.onSidebarActive),
      unselectedIconTheme: IconThemeData(color: palette.onSidebar),
      selectedLabelTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: palette.onSidebar,
      ),
      unselectedLabelTextStyle: TextStyle(color: palette.onSidebar),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: palette.sidebar,
      indicatorColor: palette.sidebarActive,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.onSidebarActive
              : palette.onSidebar,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? palette.onSidebarActive
              : palette.onSidebar,
        ),
      ),
    ),
  );
}
