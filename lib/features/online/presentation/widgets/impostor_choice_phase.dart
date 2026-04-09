import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';

class ImpostorChoicePhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;

  const ImpostorChoicePhase({
    super.key,
    required this.matchId,
    required this.myState,
  });

  @override
  ConsumerState<ImpostorChoicePhase> createState() =>
      _ImpostorChoicePhaseState();
}

class _ImpostorChoicePhaseState extends ConsumerState<ImpostorChoicePhase>
    with SingleTickerProviderStateMixin {
  bool _submitting = false;
  late AnimationController _pulseController;

  bool get _isEliminatedImpostor =>
      widget.myState.isImpostor && widget.myState.myIsEliminated;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEliminatedImpostor) {
      return _buildImpostorView();
    }
    return _buildWaitingView();
  }

  // ─── Eliminated Impostor's Screen ───

  Widget _buildImpostorView() {
    return SafeArea(
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
              'Fuiste eliminado',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Como eras impostor, puedes intentar adivinar la palabra secreta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _capitalize(widget.myState.category),
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Impostor hint (if enabled)
            if (widget.myState.hintsEnabled && widget.myState.myHint != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 20,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Tu pista: ',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: widget.myState.myHint!,
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Primary: Guess
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _handleChoice('guess'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Arriesgar e intentar adivinar',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary: Skip
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _handleChoice('skip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'No arriesgar',
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ─── Other Players' Waiting Screen ───

  Widget _buildWaitingView() {
    final playersAsync = ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final players = playersAsync.value ?? [];

    // Find the eliminated impostor
    final eliminatedImpostor = players
        .where((p) => p.isImpostor && p.isEliminated)
        .lastOrNull;

    final impostorName = eliminatedImpostor?.displayName ?? '???';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Pulsing icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.psychology_rounded,
                  size: 48,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'El impostor esta decidiendo...',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta eligiendo si arriesgar e intentar adivinar la palabra secreta o no.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Eliminated impostor name card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        impostorName.characters.first.toUpperCase(),
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          impostorName,
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Impostor eliminado',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.6),
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ─── Actions ───

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _handleChoice(String choice) async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onlineMatchRepositoryProvider).impostorMakeChoice(
            matchId: widget.matchId,
            choice: choice,
          );
      if (mounted) {
        ref.invalidate(myMatchStateProvider(widget.matchId));
        ref.invalidate(onlineMatchProvider(widget.matchId));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}
