/// Colour that staff give to a task so participants can recognise it
/// ("woodwork is always blue"). Colours and contrast live in `lib/theme.dart`
/// (`TaskColorStyle`); this enum stays free of Flutter imports.
///
/// Mustard is intentionally missing: it means "plan changed" everywhere.
enum TaskColor {
  petrol('Petrol'),
  blue('Blue'),
  lavender('Lavender'),
  rose('Rose'),
  apricot('Apricot'),
  sand('Sand'),
  sage('Sage'),
  slate('Slate');

  final String label;
  const TaskColor(this.label);
}
