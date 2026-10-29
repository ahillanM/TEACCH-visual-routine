import 'package:flutter/widgets.dart';

import 'app_services.dart';

/// Makes [AppServices] available to the widget tree.
///
/// Widgets subscribe to the specific store they need (e.g. with
/// `ListenableBuilder(listenable: AppScope.of(context).schedule, …)`), which
/// keeps auth, schedule, change and support state logically separate.
class AppScope extends InheritedWidget {
  final AppServices services;

  const AppScope({super.key, required this.services, required super.child});

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services != oldWidget.services;
}
