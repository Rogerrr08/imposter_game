import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const _kThemeKey = 'is_dark_mode';

/// Valor inicial del modo oscuro inyectado desde `main()` para evitar
/// el flash light→dark al arrancar. Se sobreescribe en `ProviderScope`
/// con el valor real leído de SharedPreferences antes de `runApp`.
final initialDarkModeProvider = Provider<bool>((ref) => false);

/// Carga la preferencia persistida del modo oscuro. Debe llamarse antes
/// de `runApp` para que el primer frame use el tema correcto.
Future<bool> loadInitialDarkMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kThemeKey) ?? false;
}

final isDarkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final initial = ref.read(initialDarkModeProvider);
    AppTheme.applyBrightness(initial);
    return initial;
  }

  Future<void> toggle() async {
    state = !state;
    AppTheme.applyBrightness(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, state);
  }
}
