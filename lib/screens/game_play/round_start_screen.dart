import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class RoundStartScreen extends ConsumerStatefulWidget {
  const RoundStartScreen({super.key});

  @override
  ConsumerState<RoundStartScreen> createState() => _RoundStartScreenState();
}

class _RoundStartScreenState extends ConsumerState<RoundStartScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      ref.read(gameProvider.notifier).startPlaying();
      context.go('/play');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startingPlayerName = ref.watch(
      gameProvider.select((g) {
        if (g == null) return null;
        return g.startingPlayerName ?? g.players.first.name;
      }),
    );

    if (startingPlayerName == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor, width: 3),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 56,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Empieza la ronda',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 18,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                startingPlayerName,
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'La ronda comienza en un momento.',
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: AppTheme.surfaceColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
