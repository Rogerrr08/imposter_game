import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_info_provider.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersionLabelAsync = ref.watch(appVersionLabelProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
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
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.psychology_alt,
                      size: 60,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'IMPOSTOR',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'El juego de la palabra secreta',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white54,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Quick Play button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/setup'),
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
                      onPressed: () => context.push('/groups'),
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
                      style: GoogleFonts.poppins(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 4),
                  appVersionLabelAsync.when(
                    data: (label) => Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white38,
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
      ),
    );
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
                'Selecciona la categoría, cantidad de impostores y el tiempo.',
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
              _pointsRow('+3', 'Impostor eliminado (si ganan impostores)'),
              _pointsRow(
                '+3',
                'Impostor adivina la palabra / Civil que descubre impostor',
              ),
              _pointsRow('+1', 'Otros impostores / civiles del equipo ganador'),
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
            decoration: const BoxDecoration(
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
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
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
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}
