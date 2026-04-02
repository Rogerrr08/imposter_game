import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';
import '../../utils/text_normalize.dart';
import 'widgets/active_game_cancel_dialog.dart';

class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key});

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final gameState = ref.read(gameProvider);
      if (gameState == null || gameState.phase != GamePhase.playing) {
        _timer?.cancel();
        return;
      }

      if (gameState.timeRemainingSeconds <= 1) {
        _timer?.cancel();
        ref.read(gameProvider.notifier).timeUp();
        if (mounted) {
          context.go('/results');
        }
      } else {
        ref.read(gameProvider.notifier).tick();
      }
    });
  }

  void _verifyImpostorAndNavigate() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) return;
    final impostorHints = gameState.activePlayers
        .where((p) => p.role == PlayerRole.impostor && p.hint != null)
        .map((p) => normalizeText(p.hint!))
        .toSet();
    if (impostorHints.isEmpty) {
      _timer?.cancel();
      context.push('/impostor-guess').then((_) {
        if (mounted) _startTimer();
      });
      return;
    }
    final hintController = TextEditingController();
    _timer?.cancel();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) => AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u{1F6A8} Verificaci\u00f3n de impostor',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.warningColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OJO: Escribe tu PISTA, NO la palabra que intentas adivinar. '
                                    'Esto es solo para verificar que eres impostor.',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: hintController,
                            autofocus: false,
                            style: GoogleFonts.nunito(color: AppTheme.textPrimary),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Escribe tu pista aquí...',
                              hintStyle: GoogleFonts.nunito(
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              ),
                              errorText: errorText,
                            ),
                            onSubmitted: (_) {
                              final input = normalizeText(hintController.text);
                              if (impostorHints.contains(input)) {
                                Navigator.pop(dialogContext, true);
                              } else {
                                setDialogState(() => errorText = 'Pista incorrecta');
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final input = normalizeText(hintController.text);
                                    if (impostorHints.contains(input)) {
                                      Navigator.pop(dialogContext, true);
                                    } else {
                                      setDialogState(() => errorText = 'Pista incorrecta');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    'Confirmar',
                                    style: GoogleFonts.nunito(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.nunito(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((verified) {
      if (verified == true && mounted) {
        context.push('/impostor-guess').then((_) {
          if (mounted) _startTimer();
        });
      } else {
        if (mounted) _startTimer();
      }
    });
  }
  void _confirmCancelGame() {
    _timer?.cancel();
    showActiveGameCancelDialog(context, ref).then((confirmed) {
      if (!confirmed && mounted) {
        _startTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.phase == GamePhase.playing &&
        (_timer == null || !(_timer?.isActive ?? false))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_timer == null || !(_timer?.isActive ?? false))) {
          _startTimer();
        }
      });
    }

    // If state already moved to results (e.g. from elimination), navigate
    if (gameState.phase == GamePhase.results) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/results');
      });
    }

    final minutes = gameState.timeRemainingSeconds ~/ 60;
    final seconds = gameState.timeRemainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final progress =
        gameState.timeRemainingSeconds / gameState.config.durationSeconds;
    final isLowTime = gameState.timeRemainingSeconds <= 30;
    final isClassicMode = gameState.config.mode == GameMode.classic;
    final eliminatedCount =
        gameState.players.where((p) => p.isEliminated).length;
    final activeCount = gameState.activePlayers.length;

    // Manage pulse animation
    if (isLowTime && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isLowTime && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _confirmCancelGame();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
            children: [
              const SizedBox(height: 16),
              // Header with mode name + cancel button
              Row(
                children: [
                  const Spacer(),
                  Text(
                    isClassicMode
                        ? '\u{1F3DB}\uFE0F Cl\u00E1sico'
                        : '\u26A1 Express',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _confirmCancelGame,
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        tooltip: 'Cancelar partida',
                      ),
                    ),
                  ),
                ],
              ),
              // Round + active players indicator (classic mode)
              if (isClassicMode) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ronda ${eliminatedCount + 1}  \u00B7  $activeCount jugadores activos',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
              if (gameState.shouldShowStartingPlayer) ...[
                const SizedBox(height: 8),
                _buildStartingPlayerBanner(gameState.startingPlayerName!),
              ],
              // Center everything vertically
              const Spacer(flex: 2),
              // Circular timer (with pulse when low time)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: _buildCircularTimer(timeString, progress, isLowTime),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Eliminated players (compact chips)
              _buildEliminatedChips(gameState),
              const Spacer(flex: 3),
              // Action buttons — clean, no repetitive text
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _timer?.cancel();
                    if (isClassicMode) {
                      ref.read(gameProvider.notifier).startVotingRound();
                    }
                    await context.push('/vote');
                    if (mounted) _startTimer();
                  },
                  icon: const Icon(Icons.how_to_vote_rounded, size: 20),
                  label: Text(isClassicMode
                      ? 'Iniciar votaci\u00F3n'
                      : 'Votar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!isClassicMode) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _verifyImpostorAndNavigate,
                    icon: const Icon(Icons.psychology_alt_rounded, size: 20),
                    label: const Text('Adivinar palabra'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryColor,
                      side: BorderSide(color: AppTheme.secondaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularTimer(
    String timeString,
    double progress,
    bool isLowTime,
  ) {
    final timerColor = isLowTime
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 10,
              color: AppTheme.surfaceColor,
            ),
          ),
          // Progress circle
          SizedBox(
            width: 180,
            height: 180,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: progress, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) {
                return Transform.rotate(
                  angle: -math.pi / 2,
                  child: CustomPaint(
                    size: const Size(180, 180),
                    painter: _CircularTimerPainter(
                      progress: value,
                      color: timerColor,
                      strokeWidth: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_rounded,
                size: 24,
                color: timerColor.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 4),
              Text(
                timeString,
                style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: timerColor,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartingPlayerBanner(String playerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Empieza: $playerName',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliminatedChips(ActiveGame gameState) {
    final eliminated = gameState.players.where((p) => p.isEliminated).toList();

    if (eliminated.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'Eliminados (${eliminated.length})',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: eliminated.map((player) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                player.name,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Custom painter for the circular timer arc.
class _CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularTimerPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

