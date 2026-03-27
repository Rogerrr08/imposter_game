import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/action_reveal.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class ActionRevealScreen extends ConsumerStatefulWidget {
  final ActionRevealData reveal;

  const ActionRevealScreen({
    super.key,
    required this.reveal,
  });

  @override
  ConsumerState<ActionRevealScreen> createState() => _ActionRevealScreenState();
}

class _ActionRevealScreenState extends ConsumerState<ActionRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showResult = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) {
      context.go('/');
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
            child: const Icon(
              Icons.visibility_rounded,
              color: AppTheme.primaryColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Revelando resultado...',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Un poco de suspenso antes de mostrar lo que pasó',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white54,
            ),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_controller.value * 100).round()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white54,
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
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          config.title,
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: config.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          config.subtitle,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white54,
          ),
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
                        : Colors.white24,
                    size: 28,
                  ),
                ),
            ],
          ),
        ],
        const Spacer(flex: 2),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: config.color,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: GoogleFonts.poppins(
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

  _RevealVisualConfig _resultConfig(ActionRevealData reveal) {
    switch (reveal.type) {
      case ActionRevealType.vote:
        if (reveal.success) {
          return const _RevealVisualConfig(
            color: AppTheme.secondaryColor,
            icon: Icons.whatshot_rounded,
            title: 'Era impostor!',
            subtitle: 'Buen trabajo, encontraron a un impostor',
            buttonLabel: 'Continuar',
          );
        }
        final actor = reveal.actorText ?? 'El civil que voto';
        final lives = reveal.livesRemaining ?? 0;
        final subtitle =
            '$actor fallo y queda eliminado.\n$lives vida${lives == 1 ? '' : 's'} restante${lives == 1 ? '' : 's'}';
        return _RevealVisualConfig(
          color: AppTheme.successColor,
          icon: Icons.sentiment_dissatisfied_rounded,
          title: 'Era inocente!',
          subtitle: subtitle,
          buttonLabel: 'Continuar',
        );
      case ActionRevealType.guess:
        if (reveal.success) {
          final actor = reveal.actorText ?? 'El impostor';
          return _RevealVisualConfig(
            color: AppTheme.secondaryColor,
            icon: Icons.celebration_rounded,
            title: 'El impostor adivino la palabra!',
            subtitle: '$actor gana 3 puntos y los demas impostores 1',
            buttonLabel: 'Ver resultados',
          );
        }
        final actor = reveal.actorText ?? 'El impostor';
        return _RevealVisualConfig(
          color: AppTheme.successColor,
          icon: Icons.close_rounded,
          title: 'Respuesta incorrecta!',
          subtitle: '$actor fallo y queda eliminado.',
          buttonLabel: 'Continuar',
        );
    }
  }
}

class _RevealVisualConfig {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _RevealVisualConfig({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });
}
