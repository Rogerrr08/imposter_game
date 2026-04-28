import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar la preferencia de tema antes del primer frame para evitar
  // el flash light→dark al arrancar.
  final initialIsDark = await loadInitialDarkMode();
  AppTheme.applyBrightness(initialIsDark);

  // Mantener la pantalla encendida mientras el app está en primer plano.
  // El juego es pass-the-phone: el teléfono queda en la mesa entre turnos
  // y no debe bloquearse. En Web el browser libera el lock al cambiar de
  // pestaña — se re-adquiere en AppLifecycleState.resumed.
  unawaited(WakelockPlus.enable());

  // Los símbolos de fechas en 'es' solo se usan en pantallas secundarias
  // (historial, grupos). Dejamos que se cargue en background para no
  // bloquear el primer frame.
  unawaited(initializeDateFormatting('es'));

  // Supabase se inicializa lazy al entrar al modo online
  // (ver SupabaseConfig.ensureInitialized). Los usuarios que solo juegan
  // local no pagan esa inicialización en cold-start.
  runApp(
    ProviderScope(
      overrides: [
        initialDarkModeProvider.overrideWithValue(initialIsDark),
      ],
      child: const ImpostorApp(),
    ),
  );
}

class ImpostorApp extends ConsumerStatefulWidget {
  const ImpostorApp({super.key});

  @override
  ConsumerState<ImpostorApp> createState() => _ImpostorAppState();
}

class _ImpostorAppState extends ConsumerState<ImpostorApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MaterialApp.router(
        title: 'Impostor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
