import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

final isDarkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  DarkModeNotifier.new,
);

class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Default to light mode
    AppTheme.applyBrightness(false);
    return false;
  }

  void toggle() {
    state = !state;
    AppTheme.applyBrightness(state);
  }
}
