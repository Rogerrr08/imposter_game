import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imposter_game/providers/theme_provider.dart';
import 'package:imposter_game/screens/home/home_screen.dart';
import 'package:imposter_game/screens/home/how_to_play_screen.dart';
import 'package:imposter_game/screens/settings/settings_screen.dart';
import 'package:imposter_game/theme/app_theme.dart';
import 'package:imposter_game/widgets/app_badge.dart';
import 'package:imposter_game/widgets/app_empty_state.dart';
import 'package:imposter_game/widgets/full_width_button.dart';
import 'package:imposter_game/widgets/player_row.dart';
import 'package:imposter_game/widgets/result_hero.dart';
import 'package:imposter_game/widgets/secret_word_card.dart';

/// Harness de capturas: renderiza pantallas a PNG (en test/screenshots/goldens)
/// cargando todas las fuentes (Nunito + Material Icons) y simulando los
/// providers necesarios. Sirve para "ver" la app sin capturas manuales y como
/// regresión visual durante el rebrand.
/// Generar/actualizar con:  flutter test --update-goldens test/screenshots
Future<void> _loadFonts() async {
  // Carga todas las familias del FontManifest (incluye MaterialIcons via
  // uses-material-design), para que los íconos no salgan como cuadritos.
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
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

Future<void> _pump(
  WidgetTester tester,
  Widget rootWithScope, {
  bool dark = true,
}) async {
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

  testWidgets('settings_dark', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(true)],
        child: _app(const SettingsScreen()),
      ),
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_dark.png'),
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

  // Preview de los componentes compartidos de resultado (Ola 3b). Sin providers:
  // se construyen con datos de muestra para validar el look unificado.
  testWidgets('result_components_dark', (tester) async {
    await _pump(tester, _app(const _ResultComponentsPreview()));
    await expectLater(
      find.byType(_ResultComponentsPreview),
      matchesGoldenFile('goldens/result_components_dark.png'),
    );
  });

  testWidgets('kit_gallery_dark', (tester) async {
    await _pump(tester, _app(const _KitGalleryPreview()));
    await expectLater(
      find.byType(_KitGalleryPreview),
      matchesGoldenFile('goldens/kit_gallery_dark.png'),
    );
  });

  testWidgets('empty_state_dark', (tester) async {
    await _pump(
      tester,
      _app(
        Scaffold(
          body: AppEmptyState(
            icon: Icons.group_add_rounded,
            title: 'No hay grupos aún',
            message:
                'Crea un grupo para guardar jugadores y llevar un historial '
                'de partidas.',
            action: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear grupo'),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(AppEmptyState),
      matchesGoldenFile('goldens/empty_state_dark.png'),
    );
  });

  // ── Variantes en tema claro ("Fiesta Sospechosa") para regresión ──
  testWidgets('home_light', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(false)],
        child: _app(const HomeScreen(), dark: false),
      ),
      dark: false,
    );
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home_light.png'),
    );
  });

  testWidgets('settings_light', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(false)],
        child: _app(const SettingsScreen(), dark: false),
      ),
      dark: false,
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_light.png'),
    );
  });

  testWidgets('how_to_play_light', (tester) async {
    await _pump(
      tester,
      ProviderScope(
        overrides: [initialDarkModeProvider.overrideWithValue(false)],
        child: _app(const HowToPlayScreen(), dark: false),
      ),
      dark: false,
    );
    await expectLater(
      find.byType(HowToPlayScreen),
      matchesGoldenFile('goldens/how_to_play_light.png'),
    );
  });
}

class _ResultComponentsPreview extends StatelessWidget {
  const _ResultComponentsPreview();

  Widget _avatar(String name, bool isImpostor) {
    final color = isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const ResultHero(
                civilsWon: true,
                title: '¡Civiles ganan!',
                subtitle: 'Todos los impostores fueron descubiertos',
              ),
              const SizedBox(height: 24),
              const SecretWordCard(word: 'Camaleón', category: 'Animales'),
              const SizedBox(height: 24),
              PlayerRow(
                position: 1,
                name: 'Yeison',
                avatar: _avatar('Yeison', false),
                isImpostor: false,
                points: 5,
                isCurrentUser: true,
              ),
              PlayerRow(
                position: 2,
                name: 'Mariana',
                avatar: _avatar('Mariana', true),
                isImpostor: true,
                points: 3,
              ),
              PlayerRow(
                position: 3,
                name: 'Sofía',
                avatar: _avatar('Sofía', false),
                isImpostor: false,
                points: 1,
                isEliminated: true,
              ),
              PlayerRow(
                position: 4,
                name: 'Diego',
                avatar: _avatar('Diego', false),
                isImpostor: false,
                points: -1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Galería del kit de componentes (Ola 5): badges y botones, para regresión.
class _KitGalleryPreview extends StatelessWidget {
  const _KitGalleryPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppBadge(label: 'Civil', color: AppTheme.neonCyan),
                  AppBadge(label: 'Impostor', color: AppTheme.neonMagenta),
                  AppBadge(label: 'Animales', color: AppTheme.neonViolet),
                  AppBadge(
                    label: 'sm',
                    color: AppTheme.neonGreen,
                    size: AppBadgeSize.sm,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FullWidthButton(
                label: 'Juego rápido',
                icon: Icons.play_arrow_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              FullWidthButton(
                label: 'Mis grupos',
                icon: Icons.group,
                outlined: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
