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

  static Future<void>? _initFuture;

  /// Inicializa Supabase de forma **idempotente** y lazy. Se puede llamar
  /// varias veces; solo la primera invocación dispara la inicialización real,
  /// las siguientes esperan (o devuelven) el mismo `Future`.
  ///
  /// Pensado para arrancar Supabase solo cuando el usuario entra al modo
  /// online (no en `main()`), para no penalizar el cold-start de usuarios
  /// que solo juegan localmente.
  static Future<void> ensureInitialized() {
    return _initFuture ??= Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Convenience accessor for the Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
