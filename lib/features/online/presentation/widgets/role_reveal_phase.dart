import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';

class RoleRevealPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;
  final bool skipAnimation;
  final bool roleConfirmed;
  final bool confirmingRole;
  final VoidCallback onConfirmRole;

  const RoleRevealPhase({
    super.key,
    required this.matchId,
    required this.myState,
    required this.skipAnimation,
    required this.roleConfirmed,
    required this.confirmingRole,
    required this.onConfirmRole,
  });

  @override
  ConsumerState<RoleRevealPhase> createState() => _RoleRevealPhaseState();
}

class _RoleRevealPhaseState extends ConsumerState<RoleRevealPhase>
    with TickerProviderStateMixin {
  bool _localConfirmed = false;
  late AnimationController _sequenceController;
  late AnimationController _shimmerController;

  // Animation phases (0.0-1.0 mapped to 3 seconds)
  late Animation<double> _suspenseOpacity; // 0.0-0.4: suspense text
  late Animation<double> _iconScale; // 0.35-0.6: icon scale-up
  late Animation<double> _iconGlow; // 0.35-0.6: glow intensity
  late Animation<double> _roleTextOpacity; // 0.6-0.75: role text
  late Animation<Offset> _roleTextSlide; // 0.6-0.75: slide up
  late Animation<double> _cardOpacity; // 0.75-1.0: word/hint card + rest

  @override
  void initState() {
    super.initState();

    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _suspenseOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.3, 0.4, curve: Curves.easeOut),
      ),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.35, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Glow ramps up to peak then settles to subtle steady-state
    _iconGlow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.25), weight: 60),
    ]).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.35, 0.80),
      ),
    );

    _roleTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.6, 0.75, curve: Curves.easeOut),
      ),
    );

    _roleTextSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.6, 0.75, curve: Curves.easeOut),
      ),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    if (widget.skipAnimation) {
      _sequenceController.value = 1.0;
    } else {
      _sequenceController.forward();
    }
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImpostor = widget.myState.isImpostor;
    final accentColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;

    // Once confirmed (from parent or local click), lock into final state
    if (widget.roleConfirmed || widget.confirmingRole) {
      _localConfirmed = true;
    }
    if (widget.skipAnimation || _localConfirmed || _sequenceController.isCompleted) {
      return _buildFinalState(isImpostor, accentColor);
    }

    return AnimatedBuilder(
      animation: _sequenceController,
      builder: (context, child) {
        final showSuspense = _sequenceController.value < 0.4;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Suspense text (fades out)
                if (showSuspense)
                  Opacity(
                    opacity: _suspenseOpacity.value.clamp(0.0, 1.0),
                    child: _buildShimmerText('Descubriendo tu rol...'),
                  ),

                // Role icon (scales up with glow)
                if (!showSuspense) ...[
                  Transform.scale(
                    scale: _iconScale.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          // Tight inner glow
                          BoxShadow(
                            color: accentColor
                                .withValues(alpha: _iconGlow.value * 0.6),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                          // Wide ambient glow
                          BoxShadow(
                            color: accentColor
                                .withValues(alpha: _iconGlow.value * 0.3),
                            blurRadius: 48,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        isImpostor
                            ? 'assets/images/player_impostor.webp'
                            : 'assets/images/player_civil.webp',
                        width: 150,
                        height: 150,
                        cacheWidth: 300,
                        cacheHeight: 300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Role text (slides up)
                  SlideTransition(
                    position: _roleTextSlide,
                    child: Opacity(
                      opacity: _roleTextOpacity.value.clamp(0.0, 1.0),
                      child: Text(
                        isImpostor ? 'Eres el Impostor' : 'Eres Civil',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Word/hint card (fades in)
                  Opacity(
                    opacity: _cardOpacity.value.clamp(0.0, 1.0),
                    child: _buildWordCard(isImpostor, accentColor),
                  ),
                ],

                const Spacer(),

                // Button appears with card
                Opacity(
                  opacity: _cardOpacity.value.clamp(0.0, 1.0),
                  child: _buildConfirmButton(accentColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerText(String text) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppTheme.textSecondary.withValues(alpha: 0.4),
                AppTheme.textPrimary,
                AppTheme.textSecondary.withValues(alpha: 0.4),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
              end: Alignment(1.0 + 2.0 * _shimmerController.value, 0),
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinalState(bool isImpostor, Color accentColor) {
    final playersAsync = ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final players = playersAsync.value ?? [];
    final confirmedCount = players.where((p) => p.roleConfirmed).length;
    final totalActive = players.where((p) => !p.isEliminated).length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // Dim role info after confirmation
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: widget.roleConfirmed ? 0.45 : 1.0,
              child: Column(
                children: [
                  // Role image (no glow in final state)
                  Image.asset(
                    isImpostor
                        ? 'assets/images/player_impostor.webp'
                        : 'assets/images/player_civil.webp',
                    width: 150,
                    height: 150,
                    cacheWidth: 300,
                    cacheHeight: 300,
                  ),
                  const SizedBox(height: 28),
                  // Role text
                  Text(
                    isImpostor ? 'Eres el Impostor' : 'Eres Civil',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Word/hint card
                  _buildWordCard(isImpostor, accentColor),
                  const SizedBox(height: 16),
                  // Match info badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _badge(
                        '${widget.myState.impostorCount} impostor${widget.myState.impostorCount > 1 ? 'es' : ''}',
                        AppTheme.secondaryColor,
                      ),
                      _badge(
                        '${(widget.myState.durationSeconds / 60).round()} min',
                        AppTheme.warningColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Help text
                  Text(
                    isImpostor
                        ? 'No conoces la palabra. Intenta pasar desapercibido con las pistas que des.'
                        : 'Da pistas que demuestren que conoces la palabra, pero sin ser demasiado obvio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Confirm button or waiting state
            if (widget.roleConfirmed)
              Column(
                children: [
                  _PulsingDots(color: accentColor),
                  const SizedBox(height: 12),
                  Text(
                    'Esperando a los demas...',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$confirmedCount/$totalActive listos',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              )
            else
              _buildConfirmButton(accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(bool isImpostor, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            isImpostor ? 'Tu pista' : 'La palabra secreta',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isImpostor
                ? (widget.myState.myHint ?? 'Sin pista')
                : (widget.myState.word ?? '???'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          if (!isImpostor) ...[
            const SizedBox(height: 12),
            _badge(_capitalize(widget.myState.category), accentColor),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmButton(Color accentColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.confirmingRole ? null : widget.onConfirmRole,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 6,
          shadowColor: accentColor.withValues(alpha: 0.35),
        ),
        child: widget.confirmingRole
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Entendido',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Three dots that pulse in staggered sequence — more thematic
/// than a spinner for a "waiting for friends" state.
class _PulsingDots extends StatefulWidget {
  final Color color;
  const _PulsingDots({required this.color});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * math.sin(t * math.pi);
            final opacity = 0.4 + 0.6 * math.sin(t * math.pi);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
