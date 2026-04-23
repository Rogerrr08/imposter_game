import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/action_reveal.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class ActionRevealScreen extends ConsumerStatefulWidget {
  final ActionRevealData reveal;

  const ActionRevealScreen({super.key, required this.reveal});

  @override
  ConsumerState<ActionRevealScreen> createState() => _ActionRevealScreenState();
}

class _ActionRevealScreenState extends ConsumerState<ActionRevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  AnimationController? _autoAdvanceController;
  bool _showResult = false;
  late final void Function(AnimationStatus) _statusListener;

  bool get _shouldAutoAdvance {
    final reveal = widget.reveal;
    if (reveal.voteTallies.isNotEmpty) return false;
    return (reveal.type == ActionRevealType.vote && !reveal.success) ||
        (reveal.type == ActionRevealType.guess && !reveal.success);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _statusListener = (status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showResult = true;
        });
        if (_shouldAutoAdvance) {
          _startAutoAdvance();
        }
      }
    };

    _controller.forward();
    _controller.addStatusListener(_statusListener);
  }

  void _startAutoAdvance() {
    _autoAdvanceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _autoAdvanceController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _continue();
      }
    });
    _autoAdvanceController!.forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_statusListener);
    _controller.dispose();
    _autoAdvanceController?.dispose();
    super.dispose();
  }

  void _continue() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) {
      context.go('/');
      return;
    }

    if (gameState.config.mode == GameMode.classic &&
        widget.reveal.type == ActionRevealType.vote &&
        widget.reveal.success &&
        gameState.awaitingClassicGuessDecision) {
      context.go('/classic-impostor-choice');
      return;
    }

    if (gameState.gameOver || gameState.phase == GamePhase.results) {
      context.go('/results');
    } else {
      context.go('/play');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _showResult ? _buildResultView() : _buildLoadingView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.visibility_rounded,
              color: AppTheme.primaryColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Revelando resultado...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Un poco de suspenso antes de mostrar lo que pasó',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 280,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 12,
                        value: _controller.value,
                        backgroundColor: AppTheme.surfaceColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_controller.value * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final config = _resultConfig(widget.reveal);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        if (config.imagePath != null)
          Image.asset(
            config.imagePath!,
            width: 180,
            height: 180,
            cacheWidth: 360,
            cacheHeight: 360,
          )
        else
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: config.color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: config.color.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(config.icon, size: 64, color: config.color),
          ),
        const SizedBox(height: 32),
        Text(
          widget.reveal.subjectText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          config.title,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: config.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          config.subtitle,
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (widget.reveal.type == ActionRevealType.vote &&
            !widget.reveal.success &&
            widget.reveal.livesRemaining != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < ActiveGame.maxLives; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    i < widget.reveal.livesRemaining!
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: i < widget.reveal.livesRemaining!
                        ? AppTheme.secondaryColor
                        : AppTheme.textSecondary.withValues(alpha: 0.3),
                    size: 28,
                  ),
                ),
            ],
          ),
        ],
        if (widget.reveal.voteTallies.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildVoteTallies(config.color),
        ],
        const Spacer(flex: 2),
        if (_shouldAutoAdvance && _autoAdvanceController != null)
          _buildAutoAdvanceBar(config.color)
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: config.color,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(config.buttonLabel),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVoteTallies(Color accentColor) {
    final tallies = widget.reveal.voteTallies;
    final sorted = tallies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVotes = sorted.first.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultados de la votaci\u00F3n',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((entry) {
            final isEliminated = entry.key == widget.reveal.subjectText;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isEliminated
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isEliminated
                            ? accentColor
                            : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fraction = entry.value / maxVotes;
                        return Stack(
                          children: [
                            Container(
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              height: 22,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(
                                color: isEliminated
                                    ? accentColor.withValues(alpha: 0.7)
                                    : AppTheme.primaryColor.withValues(
                                        alpha: 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isEliminated ? accentColor : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAutoAdvanceBar(Color color) {
    return AnimatedBuilder(
      animation: _autoAdvanceController!,
      builder: (context, _) {
        return Column(
          children: [
            GestureDetector(
              onTap: _continue,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    // Depleting fill
                    FractionallySizedBox(
                      widthFactor: 1.0 - _autoAdvanceController!.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    // Text
                    Center(
                      child: Text(
                        'Siguiente...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _autoAdvanceController!.value < 0.5
                              ? Colors.white
                              : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _RevealVisualConfig _resultConfig(ActionRevealData reveal) {
    switch (reveal.type) {
      case ActionRevealType.vote:
        if (reveal.success) {
          return _RevealVisualConfig(
            color: AppTheme.secondaryColor,
            imagePath: 'assets/images/civil_correct_guess.webp',
            title: '\u00A1Era impostor!',
            subtitle: 'Buen trabajo, encontraron a un impostor.',
            buttonLabel: 'Continuar',
          );
        }
        final actor = reveal.actorText == null
            ? 'La mayor\u00EDa del grupo'
            : reveal.actorText!;
        final lives = reveal.livesRemaining ?? 0;
        final subtitle = reveal.livesRemaining == null
            ? '$actor vot\u00F3 a un civil y queda eliminado.'
            : '$actor fall\u00F3 y queda eliminado.\n$lives vida${lives == 1 ? '' : 's'} restante${lives == 1 ? '' : 's'}';
        return _RevealVisualConfig(
          color: AppTheme.successColor,
          imagePath: 'assets/images/civil_lose_life.webp',
          title: '\u00A1Era inocente!',
          subtitle: subtitle,
          buttonLabel: 'Continuar',
        );
      case ActionRevealType.guess:
        if (reveal.success) {
          final actor = reveal.actorText ?? 'El impostor';
          return _RevealVisualConfig(
            color: AppTheme.secondaryColor,
            imagePath: 'assets/images/impostor_correct_guess.webp',
            title: '\u00A1El impostor adivin\u00F3 la palabra!',
            subtitle: '$actor gana 3 puntos y los dem\u00E1s impostores 1',
            buttonLabel: 'Ver resultados',
          );
        }
        final actor = reveal.actorText ?? 'El impostor';
        return _RevealVisualConfig(
          color: AppTheme.successColor,
          imagePath: 'assets/images/impostor_failed_guess.webp',
          title: '\u00A1Respuesta incorrecta!',
          subtitle: '$actor fall\u00F3 y queda eliminado.',
          buttonLabel: 'Continuar',
        );
      case ActionRevealType.guessSkipped:
        final actor = reveal.actorText ?? 'El impostor';
        return _RevealVisualConfig(
          color: AppTheme.warningColor,
          imagePath: 'assets/images/player_impostor.webp',
          title: 'No quiso arriesgar',
          subtitle: '$actor prefiri\u00F3 no intentar adivinar la palabra.',
          buttonLabel: 'Continuar',
        );
    }
  }
}

class _RevealVisualConfig {
  final Color color;
  final IconData? icon;
  final String? imagePath;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _RevealVisualConfig({
    required this.color,
    this.icon,
    this.imagePath,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}
