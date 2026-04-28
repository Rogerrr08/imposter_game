import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
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
              MediaQuery.viewInsetsOf(context).bottom + 24,
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.warningColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '\u{26A0}\u{FE0F}',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'OJO: Escribe tu PISTA, NO la palabra que intentas adivinar. '
                                    'Esto es solo para verificar que eres impostor.',
                                    style: TextStyle(
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
                            style: TextStyle(color: AppTheme.textPrimary),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Escribe tu pista aquí...',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              errorText: errorText,
                            ),
                            onSubmitted: (_) {
                              final input = normalizeText(hintController.text);
                              if (impostorHints.contains(input)) {
                                Navigator.pop(dialogContext, true);
                              } else {
                                setDialogState(
                                  () => errorText = 'Pista incorrecta',
                                );
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
                                    final input = normalizeText(
                                      hintController.text,
                                    );
                                    if (impostorHints.contains(input)) {
                                      Navigator.pop(dialogContext, true);
                                    } else {
                                      setDialogState(
                                        () => errorText = 'Pista incorrecta',
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Confirmar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Side effects on phase transitions (out of build).
    ref.listen<GamePhase?>(gameProvider.select((g) => g?.phase), (prev, next) {
      if (next == GamePhase.playing &&
          (_timer == null || !(_timer?.isActive ?? false))) {
        _startTimer();
      }
      if (next == GamePhase.results && mounted) {
        context.go('/results');
      }
    });

    // Null-state guard.
    final isNull = ref.watch(gameProvider.select((g) => g == null));
    if (isNull) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Granular selects so the screen does NOT rebuild on every timer tick.
    final isClassicMode = ref.watch(
      gameProvider.select((g) => g?.config.mode == GameMode.classic),
    );
    final durationSeconds = ref.watch(
      gameProvider.select((g) => g?.config.durationSeconds ?? 0),
    );
    final eliminatedCount = ref.watch(
      gameProvider.select(
        (g) => g?.players.where((p) => p.isEliminated).length ?? 0,
      ),
    );
    final activeCount = ref.watch(
      gameProvider.select((g) => g?.activePlayers.length ?? 0),
    );
    final showStartingPlayer = ref.watch(
      gameProvider.select((g) => g?.shouldShowStartingPlayer ?? false),
    );
    final startingPlayerName = ref.watch(
      gameProvider.select((g) => g?.startingPlayerName),
    );

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
                      style: TextStyle(
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
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.5,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ronda ${eliminatedCount + 1}  \u00B7  $activeCount jugadores activos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (showStartingPlayer && startingPlayerName != null) ...[
                  const SizedBox(height: 8),
                  _buildStartingPlayerBanner(startingPlayerName),
                ],
                // Center everything vertically
                const Spacer(flex: 2),
                // Circular timer (isolated widget — rebuilds only on seconds change)
                _CircularTimer(durationSeconds: durationSeconds),
                const SizedBox(height: 12),
                // Eliminated players (compact chips) — listens with its own select
                const _EliminatedChips(),
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
                    label: Text(
                      isClassicMode ? 'Iniciar votaci\u00F3n' : 'Votar',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
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
                        textStyle: const TextStyle(
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
              style: TextStyle(
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
}

/// Circular timer widget. Rebuilds only when `timeRemainingSeconds` changes
/// (via Riverpod `select`). Owns its own pulse animation controller, which
/// is driven by `ref.listen` to avoid side effects in `build()`.
class _CircularTimer extends ConsumerStatefulWidget {
  final int durationSeconds;
  const _CircularTimer({required this.durationSeconds});

  @override
  ConsumerState<_CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends ConsumerState<_CircularTimer>
    with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Drive pulse animation reactively — outside build side effects.
    ref.listen<bool>(
      gameProvider.select((g) => g != null && g.timeRemainingSeconds <= 30),
      (_, isLowTime) {
        if (isLowTime && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!isLowTime && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }
      },
    );

    final seconds = ref.watch(
      gameProvider.select((g) => g?.timeRemainingSeconds ?? 0),
    );
    final isLowTime = seconds <= 30;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final progress = widget.durationSeconds == 0
        ? 0.0
        : seconds / widget.durationSeconds;
    final timerColor = isLowTime
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    color: AppTheme.surfaceColor,
                  ),
                ),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Transform.rotate(
                    angle: -math.pi / 2,
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: _CircularTimerPainter(
                        progress: progress,
                        color: timerColor,
                        strokeWidth: 10,
                      ),
                    ),
                  ),
                ),
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
                      style: TextStyle(
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
          ),
        );
      },
    );
  }
}

/// Eliminated-players chip list. Rebuilds only when the eliminated set
/// changes (via `select` on the filtered list).
class _EliminatedChips extends ConsumerWidget {
  const _EliminatedChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eliminated = ref.watch(
      gameProvider.select(
        (g) => g == null
            ? const <String>[]
            : g.players
                  .where((p) => p.isEliminated)
                  .map((p) => p.name)
                  .toList(),
      ),
    );

    if (eliminated.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'Eliminados (${eliminated.length})',
          style: TextStyle(
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
          children: eliminated.map((name) {
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
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppTheme.textSecondary.withValues(
                    alpha: 0.6,
                  ),
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
