import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const _kThemeKey = 'is_dark_mode';

final isDarkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    AppTheme.applyBrightness(false);
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kThemeKey) ?? false;
    if (isDark != state) {
      state = isDark;
      AppTheme.applyBrightness(isDark);
    }
  }

  Future<void> toggle() async {
    state = !state;
    AppTheme.applyBrightness(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, state);
  }
}
