import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration via `--dart-define` (§0 rule 6, §6.1).
/// Never hard-codes secrets or the `service_role` key in source code.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static String get publishableKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initializeIfConfigured() async {
    if (_initialized || !isConfigured) {
      return;
    }
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
    _initialized = true;
  }

  static SupabaseClient? get clientOrNull =>
      _initialized ? Supabase.instance.client : null;
}
