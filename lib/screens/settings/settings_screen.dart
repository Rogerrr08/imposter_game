import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_info_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

/// Pantalla de Ajustes: hogar del tema y la info del juego. Antes el toggle de
/// tema vivía suelto como un ícono en el Home, sin acceso desde el resto del app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final version = ref.watch(appVersionLabelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp16,
          vertical: AppTheme.sp8,
        ),
        children: [
          _section('Apariencia'),
          SwitchListTile(
            value: isDark,
            onChanged: (_) => ref.read(isDarkModeProvider.notifier).toggle(),
            secondary: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            title: const Text('Modo oscuro'),
            subtitle: Text(
              isDark ? 'Neón fiesta nocturna' : 'Fiesta sospechosa',
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
          _section('Información'),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Cómo jugar'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/how-to-play'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Versión'),
            trailing: Text(
              version,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.sp4,
          AppTheme.sp12,
          0,
          AppTheme.sp4,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
      );
}
