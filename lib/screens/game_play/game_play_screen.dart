import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
    final progress = gameState.timeRemainingSeconds /
        gameState.config.durationSeconds;
    final isLowTime = gameState.timeRemainingSeconds <= 30;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Header
              Text(
                'Discusion en curso',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              // Circular timer
              _buildCircularTimer(timeString, progress, isLowTime),
              const SizedBox(height: 20),
              // Lives indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < ActiveGame.maxLives; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        i < gameState.livesRemaining
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: i < gameState.livesRemaining
                            ? AppTheme.secondaryColor
                            : Colors.white24,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${gameState.livesRemaining} vida${gameState.livesRemaining == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: gameState.livesRemaining == 1
                          ? AppTheme.secondaryColor
                          : Colors.white54,
                      fontWeight: gameState.livesRemaining == 1
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Player list header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Jugadores',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Player list
              Expanded(
                child: _buildPlayerList(gameState),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/vote'),
                      icon: const Icon(Icons.how_to_vote_rounded, size: 22),
                      label: const Text('Votar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/impostor-guess'),
                      icon: const Icon(Icons.psychology_alt_rounded, size: 22),
                      label: const Text(
                        'Impostor adivina',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondaryColor,
                        side: const BorderSide(color: AppTheme.secondaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularTimer(
      String timeString, double progress, bool isLowTime) {
    final timerColor = isLowTime ? AppTheme.secondaryColor : AppTheme.primaryColor;

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
                style: GoogleFonts.poppins(
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

  Widget _buildPlayerList(ActiveGame gameState) {
    return ListView.separated(
      itemCount: gameState.players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final player = gameState.players[index];
        final isEliminated = player.isEliminated;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isEliminated
                ? AppTheme.surfaceColor.withValues(alpha: 0.5)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEliminated
                  ? Colors.white12
                  : AppTheme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEliminated
                      ? Colors.white12
                      : AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    player.name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isEliminated ? Colors.white24 : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Player name
              Expanded(
                child: Text(
                  player.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEliminated ? Colors.white30 : Colors.white,
                    decoration:
                        isEliminated ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white30,
                  ),
                ),
              ),
              // Status icon
              if (isEliminated)
                const Icon(
                  Icons.close_rounded,
                  color: AppTheme.secondaryColor,
                  size: 22,
                )
              else
                Icon(
                  Icons.circle,
                  color: AppTheme.successColor.withValues(alpha: 0.6),
                  size: 12,
                ),
            ],
          ),
        );
      },
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
