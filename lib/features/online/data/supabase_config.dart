import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project configuration.
/// Values are injected at build time via --dart-define or .env file.
class SupabaseConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ndylollromihycdjulbc.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_za43G7VIarX-gV8bWyEEqQ_eODBdShj',
  );

  /// Initialize Supabase. Call once in main() before runApp.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Convenience accessor for the Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
