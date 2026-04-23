import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar la preferencia de tema antes del primer frame para evitar
  // el flash light→dark al arrancar.
  final initialIsDark = await loadInitialDarkMode();
  AppTheme.applyBrightness(initialIsDark);

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

class ImpostorApp extends ConsumerWidget {
  const ImpostorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
