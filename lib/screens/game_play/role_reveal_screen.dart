import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

// Panel colors are resolved at runtime based on theme brightness
// See AppTheme.panelColors(isDark)

class RoleRevealScreen extends ConsumerStatefulWidget {
  const RoleRevealScreen({super.key});

  @override
  ConsumerState<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends ConsumerState<RoleRevealScreen>
    with SingleTickerProviderStateMixin {
  bool _hasRevealed = false;
  double _dragOffset = 0;
  late final AnimationController _snapBackController;
  double _snapFrom = 0;

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        final curved = Curves.easeOut.transform(_snapBackController.value);
        setState(() {
          _dragOffset = lerpDouble(_snapFrom, 0, curved) ?? 0;
        });
      });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }

    final maxDrag = -MediaQuery.of(context).size.height * 0.85;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(maxDrag, 0.0);

      // Enable button as soon as user drags up a little
      if (!_hasRevealed && _dragOffset < -40) {
        _hasRevealed = true;
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;

    // Also enable on any upward flick
    if (!_hasRevealed && (velocity < -200 || _dragOffset < -40)) {
      setState(() => _hasRevealed = true);
    }

    _snapFrom = _dragOffset;
    _snapBackController.forward(from: 0);
  }

  void _nextPlayer() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) return;

    final isLastPlayer =
        gameState.currentRevealIndex >= gameState.players.length - 1;

    if (isLastPlayer) {
      context.go('/round-start');
      return;
    }

    ref.read(gameProvider.notifier).nextReveal();
    setState(() {
      _hasRevealed = false;
      _dragOffset = 0;
      _snapFrom = 0;
      _snapBackController.reset();
    });
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
    final isLastPlayer = gameState.currentRevealIndex >= totalPlayers - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.panelColors(isDark);
    final panelColor =
        colors[gameState.currentRevealIndex % colors.length];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildProgressBar(playerNumber, totalPlayers),
              const SizedBox(height: 8),
              Text(
                'Jugador $playerNumber de $totalPlayers',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background: Role info, aligned to bottom
                      Positioned.fill(
                        child:
                            _buildRoleInfo(currentPlayer, gameState),
                      ),
                      // Foreground: Draggable cover panel
                      Positioned.fill(
                        child: GestureDetector(
                          onVerticalDragUpdate: _onDragUpdate,
                          onVerticalDragEnd: _onDragEnd,
                          child: Transform.translate(
                            offset: Offset(0, _dragOffset),
                            child: _buildCoverPanel(
                                currentPlayer, panelColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasRevealed ? _nextPlayer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPlayer
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                      disabledBackgroundColor:
                          AppTheme.textSecondary.withValues(alpha: 0.18),
                      disabledForegroundColor:
                          AppTheme.textSecondary.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      isLastPlayer ? 'Empezar Juego' : 'Jugador Siguiente',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildCoverPanel(GamePlayer player, Color color) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              Color.alphaBlend(
                Colors.black.withValues(alpha: 0.15),
                color,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Player name - main focus
              Text(
                player.name,
                style: GoogleFonts.poppins(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Logo image
              Expanded(
                flex: 4,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      'assets/images/app_logo_no_bg.png',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // Drag hint
              Icon(
                Icons.keyboard_double_arrow_up_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                'Desliza hacia arriba para\nrevelar tu rol',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '\u00A1Que nadie m\u00E1s vea la pantalla!',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleInfo(GamePlayer player, ActiveGame gameState) {
    final isImpostor = player.role == PlayerRole.impostor;
    final roleColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.successColor;

    return Column(
      children: [
        // Push content toward the bottom so it's visible with a small drag
        const Spacer(flex: 1),
        // Role image
        Image.asset(
          isImpostor
              ? 'assets/images/player_impostor.png'
              : 'assets/images/player_civil.png',
          width: 110,
          height: 110,
        ),
        const SizedBox(height: 8),
        // Role text
        Text(
          isImpostor ? 'IMPOSTOR' : 'CIVIL',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: roleColor,
          ),
        ),
        const SizedBox(height: 14),
        // Word / hint card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isImpostor) ...[
                  Text(
                    'La palabra secreta es:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    gameState.secretWord,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  if (player.hint != null) ...[
                    Text(
                      'Tu pista:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                    Icon(
                      Icons.block_rounded,
                      size: 28,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No tienes pistas',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Descubre la palabra escuchando a los dem\u00E1s',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pasa al siguiente jugador.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
