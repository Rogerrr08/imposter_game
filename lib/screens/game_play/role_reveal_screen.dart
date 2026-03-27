import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';

class RoleRevealScreen extends ConsumerStatefulWidget {
  const RoleRevealScreen({super.key});

  @override
  ConsumerState<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends ConsumerState<RoleRevealScreen>
    with SingleTickerProviderStateMixin {
  bool _revealed = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _revealed = true);
    _animController.forward(from: 0);
  }

  void _hideAndNext() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) return;

    _animController.reset();

    final isLastPlayer =
        gameState.currentRevealIndex >= gameState.players.length - 1;

    if (isLastPlayer) {
      ref.read(gameProvider.notifier).startPlaying();
      context.go('/play');
    } else {
      ref.read(gameProvider.notifier).nextReveal();
      setState(() => _revealed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPlayer = gameState.players[gameState.currentRevealIndex];
    final playerNumber = gameState.currentRevealIndex + 1;
    final totalPlayers = gameState.players.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Progress indicator
              _buildProgressBar(playerNumber, totalPlayers),
              const SizedBox(height: 16),
              Text(
                'Jugador $playerNumber de $totalPlayers',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const Spacer(flex: 2),
              if (!_revealed) ...[
                _buildPreReveal(currentPlayer.name),
              ] else ...[
                _buildPostReveal(currentPlayer, gameState),
              ],
              const Spacer(flex: 2),
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _revealed ? _hideAndNext : _reveal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _revealed
                        ? AppTheme.secondaryColor
                        : AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    _revealed ? 'Ocultar y Pasar' : 'Revelar Rol',
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int current, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: current / total,
        minHeight: 6,
        backgroundColor: AppTheme.surfaceColor,
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildPreReveal(String playerName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryColor, width: 3),
          ),
          child: const Icon(
            Icons.visibility_off_rounded,
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Pasa el telefono a',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          playerName,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Asegurate de que nadie mas vea la pantalla',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white38,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPostReveal(GamePlayer player, ActiveGame gameState) {
    final isImpostor = player.role == PlayerRole.impostor;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Role icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: (isImpostor
                        ? AppTheme.secondaryColor
                        : AppTheme.successColor)
                    .withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isImpostor
                      ? AppTheme.secondaryColor
                      : AppTheme.successColor,
                  width: 3,
                ),
              ),
              child: Icon(
                isImpostor
                    ? Icons.psychology_alt_rounded
                    : Icons.shield_rounded,
                size: 54,
                color: isImpostor
                    ? AppTheme.secondaryColor
                    : AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),
            // Player name
            Text(
              player.name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            // Role text
            Text(
              isImpostor ? 'IMPOSTOR' : 'CIVIL',
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: isImpostor
                    ? AppTheme.secondaryColor
                    : AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),
            // Word or hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isImpostor
                          ? AppTheme.secondaryColor
                          : AppTheme.successColor)
                      .withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (!isImpostor) ...[
                    Text(
                      'La palabra secreta es:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gameState.secretWord,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    if (player.hint != null) ...[
                      Text(
                        'Tu pista:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        player.hint!,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warningColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Icon(
                        Icons.block_rounded,
                        size: 32,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No tienes pistas',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Descubre la palabra escuchando a los demas',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
