/// Client configuration, overridable with `--dart-define=NAME=value`.
///
/// Only PUBLIC values belong here. The Supabase publishable key is designed to
/// ship in apps (RLS protects the data). Never add a Supabase service-role key
/// or the OpenRouter key: those stay in the FastAPI backend's environment.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://byuyanzfawjbuzlzbpev.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8TPJYscN6tp1_yhFHOvAEw_uoMkUNRN',
  );

  /// FastAPI AI backend. Android emulator: http://10.0.2.2:8000.
  static const aiBackendUrl = String.fromEnvironment(
    'AI_BACKEND_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Optional shared key if the backend sets AI_BACKEND_API_KEY. A value
  /// compiled into an app is not a real secret; use it only to keep casual
  /// traffic off a demo server.
  static const aiBackendApiKey = String.fromEnvironment('AI_BACKEND_API_KEY');

  /// `--dart-define=USE_MOCK_DATA=true` runs the offline prototype.
  static const useMockData = bool.fromEnvironment('USE_MOCK_DATA');
}
