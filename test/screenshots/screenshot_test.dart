import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imposter_game/providers/theme_provider.dart';
import 'package:imposter_game/screens/home/home_screen.dart';
import 'package:imposter_game/theme/app_theme.dart';

/// Harness de capturas: renderiza pantallas a PNG (en test/screenshots/goldens)
/// cargando la fuente Nunito real y simulando los providers necesarios.
/// Generar/actualizar con:  flutter test --update-goldens test/screenshots
Future<void> _loadFonts() async {
  final loader = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'));
  await loader.load();
}

Widget _app(Widget screen, {bool dark = true}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: screen,
    );

Future<void> _pump(WidgetTester tester, Widget rootWithScope,
    {bool dark = true}) async {
  AppTheme.applyBrightness(dark);
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  addTearDown(tester.view.reset);

  // runAsync permite que los Image.asset (.webp) carguen de verdad.
  await tester.runAsync(() async {
    await tester.pumpWidget(rootWithScope);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  testWidgets('home_dark', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(true)],
        child: _app(const HomeScreen()),
      ),
    );
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_dark.png'),
    );
  });
}
