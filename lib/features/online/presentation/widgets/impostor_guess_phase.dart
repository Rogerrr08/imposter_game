import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';
import 'player_avatar.dart';

class ImpostorGuessPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;

  const ImpostorGuessPhase({
    super.key,
    required this.matchId,
    required this.myState,
  });

  @override
  ConsumerState<ImpostorGuessPhase> createState() => _ImpostorGuessPhaseState();
}

class _ImpostorGuessPhaseState extends ConsumerState<ImpostorGuessPhase> {
  final _guessController = TextEditingController();
  bool _submitting = false;
  Timer? _timer;
  int _secondsLeft = 30;

  /// Whether the current user is the eliminated impostor who should guess.
  bool get _isGuesser =>
      widget.myState.isImpostor && widget.myState.myIsEliminated;

  @override
  void initState() {
    super.initState();
    if (_isGuesser) {
      _guessController.addListener(() => setState(() {}));
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _guessController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _handleSkip();
      }
    });
  }

  Future<void> _handleSubmitGuess() async {
    final guess = _guessController.text.trim();
    if (guess.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      await ref
          .read(onlineMatchRepositoryProvider)
          .submitImpostorGuess(matchId: widget.matchId, guess: guess);

      if (mounted) {
        // Force immediate refresh for phase transition
        ref.invalidate(myMatchStateProvider(widget.matchId));
        ref.invalidate(onlineMatchProvider(widget.matchId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      await ref
          .read(onlineMatchRepositoryProvider)
          .skipImpostorGuess(widget.matchId);

      if (mounted) {
        ref.invalidate(myMatchStateProvider(widget.matchId));
        ref.invalidate(onlineMatchProvider(widget.matchId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuesser) {
      return _buildGuesserView();
    }
    return _buildWaitingView();
  }

  // ─── Guesser view (eliminated impostor) ──────────────────────────

  Widget _buildGuesserView() {
    final timerColor = _secondsLeft <= 10
        ? AppTheme.errorColor
        : _secondsLeft <= 15
            ? AppTheme.warningColor
            : AppTheme.textSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Timer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: timerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 18, color: timerColor),
                        const SizedBox(width: 6),
                        Text(
                          '${_secondsLeft}s',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: timerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.secondaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.secondaryColor, width: 3),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      size: 48,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Intenta adivinar la palabra',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe la palabra secreta que crees que es',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Hint reminder (no category — impostor shouldn't see it)
                  if (widget.myState.myHint != null)
                    _badge('Pista: ${widget.myState.myHint!}',
                        AppTheme.secondaryColor),
                  const SizedBox(height: 28),
                  // Guess input
                  TextField(
                    controller: _guessController,
                    autofocus: true,
                    enabled: !_submitting,
                    maxLength: 40,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                      hintStyle: TextStyle(fontFamily: 'Nunito',
                        fontSize: 16,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppTheme.secondaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                    ),
                    onSubmitted: (_) => _handleSubmitGuess(),
                  ),
                  const SizedBox(height: 16),
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningColor,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Si aciertas, los impostores ganan. Si fallas, el juego continua.',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 12,
                              color: AppTheme.warningColor
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ||
                              _guessController.text.trim().isEmpty
                          ? null
                          : _handleSubmitGuess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        disabledBackgroundColor:
                            AppTheme.secondaryColor.withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
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
                              'Confirmar',
                              style: TextStyle(fontFamily: 'Nunito',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _handleSkip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(
                          color:
                              AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Pasar',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Waiting view (everyone else) ─────────────────────────────────

  Widget _buildWaitingView() {
    final playersAsync =
        ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final players = playersAsync.value ?? [];
    final eliminatedImpostor = players
        .where((p) => p.isImpostor && p.isEliminated)
        .lastOrNull;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                    AppTheme.secondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.5),
                    width: 2),
              ),
              child: Icon(
                Icons.psychology_rounded,
                size: 48,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'El impostor está intentando\nadivinar la palabra...',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            if (eliminatedImpostor != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.secondaryColor
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatar(
                      displayName: eliminatedImpostor.displayName,
                      avatarUrl: eliminatedImpostor.avatarUrl,
                      size: 36,
                      backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.15),
                      textColor: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eliminatedImpostor.displayName,
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 15,
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
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppTheme.secondaryColor,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esperando...',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


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
