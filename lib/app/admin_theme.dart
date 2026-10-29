import 'package:flutter/widgets.dart';

/// Staff-only light/dark preference. Participants always see the light
/// theme. Kept for the session only – the app has no preference storage yet.
class AdminThemeController extends ValueNotifier<bool> {
  AdminThemeController({bool dark = false}) : super(dark);

  bool get isDark => value;

  void toggle() => value = !value;
}

/// Makes the [AdminThemeController] available to the staff UI.
class AdminThemeScope extends InheritedNotifier<AdminThemeController> {
  const AdminThemeScope({
    super.key,
    required AdminThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminThemeScope>();
    assert(scope != null, 'AdminThemeScope not found in the widget tree');
    return scope!.notifier!;
  }
}
