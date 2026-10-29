import 'package:flutter/material.dart';

import 'app/planner_app.dart';

/// MVP entry point: login + role-aware participant / staff interfaces.
///
///   flutter run -d chrome -t lib/main_mvp.dart
///
/// `lib/main.dart` (the original demo role switcher) is left untouched until
/// final integration; switching it over is a one-line change:
///   runApp(const PlannerApp());
void main() {
  runApp(const PlannerApp());
}
