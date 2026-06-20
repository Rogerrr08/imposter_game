import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imposter_game/providers/theme_provider.dart';
import 'package:imposter_game/screens/home/home_screen.dart';
import 'package:imposter_game/screens/home/how_to_play_screen.dart';
import 'package:imposter_game/theme/app_theme.dart';

/// Harness de capturas: renderiza pantallas a PNG (en test/screenshots/goldens)
/// cargando todas las fuentes (Nunito + Material Icons) y simulando los
/// providers necesarios. Sirve para "ver" la app sin capturas manuales y como
/// regresión visual durante el rebrand.
/// Generar/actualizar con:  flutter test --update-goldens test/screenshots
Future<void> _loadFonts() async {
  // Carga todas las familias del FontManifest (incluye MaterialIcons via
  // uses-material-design), para que los íconos no salgan como cuadritos.
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  // Asegura Nunito aunque no esté en el manifest del entorno de test.
  final nunito = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'));
  await nunito.load();
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

  testWidgets('how_to_play_dark', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(true)],
        child: _app(const HowToPlayScreen()),
      ),
    );
    await expectLater(
      find.byType(HowToPlayScreen),
      matchesGoldenFile('goldens/how_to_play_dark.png'),
    );
  });
}
