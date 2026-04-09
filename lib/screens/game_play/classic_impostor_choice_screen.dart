import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/action_reveal.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class ClassicImpostorChoiceScreen extends ConsumerWidget {
  const ClassicImpostorChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final guesserName = game?.pendingClassicGuesserName;

    if (game == null || guesserName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/play');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/images/player_impostor.webp',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 24),
              Text(
                '$guesserName fue eliminado',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Como era impostor, ahora puede intentar adivinar la palabra secreta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/impostor-guess'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: TextStyle(fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Arriesgar e intentar adivinar'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(gameProvider.notifier).skipClassicImpostorGuess();
                    context.go(
                      '/action-reveal',
                      extra: ActionRevealData(
                        type: ActionRevealType.guessSkipped,
                        success: false,
                        subjectText: guesserName,
                        actorText: guesserName,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: TextStyle(fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('No arriesgar'),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
