import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Full-screen countdown transition: "Revelando resultados..." with 3-2-1.
class RevealCountdown extends StatefulWidget {
  final int durationSeconds;
  final VoidCallback? onComplete;

  const RevealCountdown({
    super.key,
    this.durationSeconds = 3,
    this.onComplete,
  });

  @override
  State<RevealCountdown> createState() => _RevealCountdownState();
}

class _RevealCountdownState extends State<RevealCountdown>
    with TickerProviderStateMixin {
  late int _current;
  Timer? _timer;

  late AnimationController _numberController;
  late Animation<double> _numberScale;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _current = widget.durationSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _numberScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.25), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeOut,
    ));

    _numberController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_current <= 1) {
        _timer?.cancel();
        widget.onComplete?.call();
        return;
      }
      setState(() => _current--);
      _numberController.reset();
      _numberController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _numberController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotsLit = widget.durationSeconds - _current + 1;
    final isLast = _current == 1;
    final numberColor = isLast ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return Container(
      color: AppTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final opacity = 0.5 + 0.5 * _pulseController.value;
                return Opacity(opacity: opacity, child: child);
              },
              child: Text(
                'Revelando resultados...',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Countdown number with glow
            SizedBox(
              width: 200,
              height: 200,
              child: AnimatedBuilder(
                animation: _numberController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _numberScale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radial glow
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                numberColor.withValues(alpha: 0.20),
                                numberColor.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        // Number
                        Text(
                          '$_current',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 120,
                            fontWeight: FontWeight.w900,
                            color: numberColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),

            // Dots indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.durationSeconds, (i) {
                final lit = i < dotsLit;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
