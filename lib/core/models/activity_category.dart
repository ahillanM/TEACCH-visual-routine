/// Semantic activity categories shared by the participant and staff UIs.
///
/// Colours, icons and labels for each category live in `lib/theme.dart`
/// (`CategoryStyle`), so this file stays free of Flutter imports.
enum ActivityCategory {
  work,
  meal,
  travel,
  support,
  freeTime,
  residential,
  personal;

  /// Maps to the category codes used by the locked legacy `ScheduleItem`
  /// model (see CLAUDE.md §3), so both models can be bridged later.
  String? get legacyCode => switch (this) {
        ActivityCategory.work => 'BBW_TRAINING',
        ActivityCategory.meal => 'BREAK',
        ActivityCategory.residential => 'RESIDENTIAL',
        ActivityCategory.personal => 'PERSONAL',
        _ => null,
      };

  static ActivityCategory fromLegacyCode(String code) => switch (code) {
        'BBW_TRAINING' => ActivityCategory.work,
        'BREAK' => ActivityCategory.meal,
        'RESIDENTIAL' => ActivityCategory.residential,
        _ => ActivityCategory.personal,
      };
}
