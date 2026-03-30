import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_info_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersionLabelAsync = ref.watch(appVersionLabelProvider);
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
                    'assets/images/app_logo_no_bg.png',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'YEISON',
                    style: GoogleFonts.poppins(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Impostor',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El juego de la palabra secreta',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Quick Play button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateWithLoading(context, '/setup'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Juego Rápido'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Groups button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateWithLoading(context, '/groups'),
                      icon: const Icon(Icons.group, size: 24),
                      label: const Text('Mis Grupos'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // How to play
                  TextButton.icon(
                    onPressed: () => _showHowToPlay(context),
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: Text(
                      'Cómo jugar',
                      style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  appVersionLabelAsync.when(
                    data: (label) => Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        letterSpacing: 0.4,
                      ),
                    ),
                    loading: () => const SizedBox(height: 18),
                    error: (_, _) => const SizedBox(height: 18),
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

  void _showHowToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cómo jugar',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _howToPlayStep('1', 'Agrega los jugadores (3-20 personas).'),
              _howToPlayStep(
                '2',
                'Selecciona las categorías, cantidad de impostores y el tiempo. La palabra se elige al azar de las categorías activas.',
              ),
              _howToPlayStep(
                '3',
                'Cada jugador ve su rol en secreto pasándose el teléfono.',
              ),
              _howToPlayStep(
                '4',
                'Los civiles conocen la palabra secreta. Los impostores NO.',
              ),
              _howToPlayStep(
                '5',
                'Discutan y hagan preguntas para encontrar al impostor.',
              ),
              _howToPlayStep(
                '6',
                'Voten para eliminar al sospechoso. Tienen 3 vidas: si votan mal 3 veces, ganan los impostores.',
              ),
              const SizedBox(height: 12),
              Text(
                'Puntuación:',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(height: 4),
              _pointsRow('+5', 'Impostor sobrevive hasta el final'),
              _pointsRow('+3', 'Impostor adivina la palabra'),
              _pointsRow('+3', 'Civil que descubre a un impostor'),
              _pointsRow('+1', 'Civil del equipo ganador que no votó mal'),
              _pointsRow('+1', 'Impostor eliminado por votación (si ganan impostores)'),
              _pointsRow('+0', 'Civil que votó mal (sin puntos aunque ganen)'),
              _pointsRow('+0', 'Impostor eliminado por adivinar mal'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _howToPlayStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointsRow(String points, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            points,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
