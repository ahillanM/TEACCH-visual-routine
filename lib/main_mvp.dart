import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_services.dart';
import 'app/planner_app.dart';
import 'services/app_config.dart';

/// MVP entry point: login + role-aware participant / staff interfaces.
///
///   flutter run -d chrome -t lib/main_mvp.dart
///
/// Uses Supabase + the FastAPI AI backend. The offline prototype with mock
/// data still runs with `--dart-define=USE_MOCK_DATA=true`.
///
/// `lib/main.dart` (the original demo role switcher) is left untouched until
/// final integration; switching it over is a one-line change:
///   runApp(const PlannerApp());
Future<void> main() async {
  if (AppConfig.useMockData) {
    runApp(const PlannerApp());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  // Restores a saved session automatically.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  runApp(PlannerApp(services: AppServices.supabase()));
}
