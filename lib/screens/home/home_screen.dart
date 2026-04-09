import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_info_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersionLabel = ref.watch(appVersionLabelProvider);
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Dark mode toggle (top right)
            Positioned(
              top: 12,
              right: 16,
              child: IconButton(
                onPressed: () => ref.read(isDarkModeProvider.notifier).toggle(),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppTheme.textSecondary,
                ),
                tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
              ),
            ),
            Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo / Title
                  Image.asset(
                    'assets/images/app_logo_no_bg.webp',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'YEISON',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Impostor',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El juego de la palabra secreta',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // ── Local play ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateWithLoading(context, '/setup'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Juego r\u00e1pido'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: TextStyle(fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateWithLoading(context, '/groups'),
                      icon: const Icon(Icons.group, size: 24),
                      label: const Text('Mis grupos'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: TextStyle(fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Divider ──
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.textSecondary.withValues(alpha: 0.15),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'o',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 13,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.textSecondary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Online play ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _navigateWithLoading(context, '/online'),
                      icon: const Icon(Icons.wifi_rounded, size: 22),
                      label: const Text('Jugar en l\u00ednea'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: TextStyle(fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // How to play
                  TextButton.icon(
                    onPressed: () => context.push('/how-to-play'),
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: Text(
                      'C\u00F3mo jugar',
                      style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appVersionLabel,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateWithLoading(BuildContext context, String route) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (context.mounted) {
      Navigator.of(context).pop();
      context.push(route);
    }
  }

}
