import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../application/online_match_provider.dart';
import '../domain/online_match.dart';
import 'widgets/clue_writing_phase.dart';
import 'widgets/impostor_guess_phase.dart';
import 'widgets/match_results_phase.dart';
import 'widgets/vote_result_phase.dart';
import 'widgets/voting_phase.dart';

class OnlineMatchScreen extends ConsumerStatefulWidget {
  final String matchId;

  const OnlineMatchScreen({super.key, required this.matchId});

  @override
  ConsumerState<OnlineMatchScreen> createState() => _OnlineMatchScreenState();
}

class _OnlineMatchScreenState extends ConsumerState<OnlineMatchScreen>
    with WidgetsBindingObserver {
  bool _abandonCalled = false;
  bool _roleConfirmed = false;
  bool _confirmingRole = false;

  // Hold vote_result on screen for at least 3 seconds
  bool _holdingVoteResult = false;
  MyMatchState? _heldVoteResultState;
  Timer? _voteResultTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _voteResultTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app goes to background or is closed, abandon the match
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _fireAndForgetAbandon();
    }
  }

  void _fireAndForgetAbandon() {
    if (_abandonCalled) return;
    _abandonCalled = true;
    ref
        .read(onlineMatchRepositoryProvider)
        .abandonMatch(widget.matchId)
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final myStateAsync = ref.watch(myMatchStateProvider(widget.matchId));
    final matchAsync = ref.watch(onlineMatchProvider(widget.matchId));

    // Listen for match changes via Realtime — refresh myMatchState on phase/version change
    ref.listen<AsyncValue<OnlineMatch?>>(
      onlineMatchProvider(widget.matchId),
      (prev, next) {
        final prevMatch = prev?.value;
        final nextMatch = next.value;
        if (nextMatch == null) return;

        if (nextMatch.status == OnlineMatchStatus.cancelled) {
          _showCancelledAndLeave();
          return;
        }

        // Refresh myMatchState when phase or version changes
        if (prevMatch != null &&
            (prevMatch.currentPhase != nextMatch.currentPhase ||
                prevMatch.stateVersion != nextMatch.stateVersion)) {
          ref.invalidate(myMatchStateProvider(widget.matchId));
        }
      },
    );

    // Listen for self-elimination (another device, or server-side)
    ref.listen<AsyncValue<MyMatchState>>(
      myMatchStateProvider(widget.matchId),
      (prev, next) {
        final prevState = prev?.value;
        final nextState = next.value;
        if (prevState != null &&
            nextState != null &&
            !prevState.myIsEliminated &&
            nextState.myIsEliminated) {
          _showEliminatedAndLeave();
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _confirmLeave,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Partida online',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
        ),
        body: myStateAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (e, _) => _buildError(e.toString()),
          data: (myState) {
            // If match is cancelled, show cancelled UI
            final match = matchAsync.value;
            if (match != null &&
                match.status == OnlineMatchStatus.cancelled) {
              return _buildCancelled();
            }
            // If player was eliminated...
            if (myState.myIsEliminated) {
              // ...but it's impostor_guess phase and they're the impostor → let them guess
              if (myState.currentPhase == OnlineMatchPhase.impostorGuess &&
                  myState.isImpostor) {
                return _buildMatchContent(myState);
              }
              // ...or it's vote_result phase → show the result before transitioning
              if (myState.currentPhase == OnlineMatchPhase.voteResult) {
                return _buildMatchContent(myState);
              }
              return _buildEliminated(myState);
            }
            return _buildMatchContent(myState);
          },
        ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Salir de la partida',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Si sales ahora seras eliminado de la partida. Si no quedan suficientes jugadores, la partida se cancelara.',
          style: GoogleFonts.nunito(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _fireAndForgetAbandon();
      context.go('/online');
    }
  }

  void _showCancelledAndLeave() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La partida fue cancelada por falta de jugadores.'),
      ),
    );
  }

  void _showEliminatedAndLeave() {
    // No snackbar needed — the UI will show the eliminated/waiting screen
  }

  Future<void> _handleConfirmRole() async {
    setState(() => _confirmingRole = true);
    try {
      await ref
          .read(onlineMatchRepositoryProvider)
          .confirmRoleReveal(widget.matchId);
      if (mounted) setState(() => _roleConfirmed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingRole = false);
    }
  }

  // ─── Match content ─────────────────────────────────────────────────

  Widget _buildMatchContent(MyMatchState myState) {
    final phase = myState.currentPhase;

    // When entering vote_result, hold it for 3 seconds
    if (phase == OnlineMatchPhase.voteResult && !_holdingVoteResult) {
      _holdingVoteResult = true;
      _heldVoteResultState = myState;
      _voteResultTimer?.cancel();
      _voteResultTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _holdingVoteResult = false;
            _heldVoteResultState = null;
          });
        }
      });
    }

    // Keep showing vote_result until 3-second hold expires
    if (_holdingVoteResult && phase != OnlineMatchPhase.voteResult) {
      return _buildVoteResult(_heldVoteResultState ?? myState);
    }

    switch (phase) {
      case OnlineMatchPhase.roleReveal:
        return _buildRoleReveal(myState);
      case OnlineMatchPhase.clueWriting:
        return _buildClueWriting(myState);
      case OnlineMatchPhase.voting:
        return _buildVoting(myState);
      case OnlineMatchPhase.voteResult:
        return _buildVoteResult(myState);
      case OnlineMatchPhase.impostorGuess:
        return _buildImpostorGuess(myState);
      case OnlineMatchPhase.finished:
        return _buildMatchResults(myState);
    }
  }

  Widget _buildClueWriting(MyMatchState myState) {
    return ClueWritingPhase(
      matchId: widget.matchId,
      myState: myState,
    );
  }

  Widget _buildVoting(MyMatchState myState) {
    return VotingPhase(
      matchId: widget.matchId,
      myState: myState,
    );
  }

  Widget _buildVoteResult(MyMatchState myState) {
    return VoteResultPhase(
      matchId: widget.matchId,
      myState: myState,
    );
  }

  Widget _buildImpostorGuess(MyMatchState myState) {
    return ImpostorGuessPhase(
      matchId: widget.matchId,
      myState: myState,
    );
  }

  Widget _buildMatchResults(MyMatchState myState) {
    return MatchResultsPhase(
      matchId: widget.matchId,
      myState: myState,
    );
  }

  Widget _buildRoleReveal(MyMatchState myState) {
    final isImpostor = myState.isImpostor;
    final accentColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // Role icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 3),
              ),
              child: Icon(
                isImpostor
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 56,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 28),
            // Role label
            Text(
              isImpostor ? 'Eres el Impostor' : 'Eres Civil',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),
            // Word or hint card
            Container(
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
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isImpostor
                        ? (myState.myHint ?? 'Sin pista')
                        : (myState.word ?? '???'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _badge(myState.category, accentColor),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Match info
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  '${myState.impostorCount} impostor${myState.impostorCount > 1 ? 'es' : ''}',
                  AppTheme.secondaryColor,
                ),
                _badge(
                  '${(myState.durationSeconds / 60).round()} min',
                  AppTheme.warningColor,
                ),
              ],
            ),
            const Spacer(),
            // Info text
            if (isImpostor)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'No conoces la palabra. Intenta pasar desapercibido con las pistas que des.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Da pistas que demuestren que conoces la palabra, pero sin ser demasiado obvio.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            // Confirm button or waiting state
            if (_roleConfirmed)
              Column(
                children: [
                  CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esperando a los demas...',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _confirmingRole ? null : () => _handleConfirmRole(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 6,
                    shadowColor: accentColor.withValues(alpha: 0.35),
                  ),
                  child: _confirmingRole
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Entendido',
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Cancelled / Eliminated states ─────────────────────────────────

  Widget _buildCancelled() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_rounded,
              size: 64,
              color: AppTheme.warningColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 20),
            Text(
              'Partida cancelada',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No quedaron suficientes jugadores para continuar la partida.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/online'),
                child: const Text('Volver al inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEliminated(MyMatchState myState) {
    // Check if the match is finished — if so, show results instead
    final matchAsync = ref.watch(onlineMatchProvider(widget.matchId));
    final match = matchAsync.value;
    if (match != null &&
        (match.status == OnlineMatchStatus.finished ||
            match.currentPhase == OnlineMatchPhase.finished)) {
      return MatchResultsPhase(
        matchId: widget.matchId,
        myState: myState,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_rounded,
              size: 64,
              color: AppTheme.secondaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 20),
            Text(
              'Fuiste eliminado',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Los demas jugadores votaron para eliminarte. Espera a que termine la partida.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppTheme.textSecondary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esperando que termine la partida...',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.secondaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar la partida',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
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
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
