import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../application/match_heartbeat_provider.dart';
import '../application/online_match_provider.dart';
import '../application/online_rooms_provider.dart';
import '../domain/online_match.dart';
import 'widgets/clue_writing_phase.dart';
import 'widgets/connection_status_banner.dart';
import 'widgets/spectator_banner.dart';
import 'widgets/impostor_choice_phase.dart';
import 'widgets/impostor_guess_phase.dart';
import 'widgets/impostor_result_hold.dart';
import 'widgets/match_results_phase.dart';
import 'widgets/role_reveal_phase.dart';
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
  bool _isReconnecting = false;
  String? _roomId; // Cached after first myMatchState load

  DateTime? _pausedAt; // Track when app went to background

  // Hold vote_result on screen for at least 4 seconds
  bool _holdingVoteResult = false;
  MyMatchState? _heldVoteResultState;
  Timer? _voteResultTimer;
  bool _pendingElimination = false;

  // Hold impostor result intermediate screen
  bool _holdingImpostorResult = false;
  String? _impostorResultType; // 'risk', 'no_risk', 'wrong_guess'
  String? _impostorName;
  String? _impostorGuessWord;
  int _impostorHoldDuration = 3;
  Timer? _impostorResultTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant OnlineMatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId) {
      // New match started (e.g. "Volver a jugar") — reset all local state
      _roleConfirmed = false;
      _confirmingRole = false;
      _isReconnecting = false;
      _roomId = null;
      _holdingVoteResult = false;
      _heldVoteResultState = null;
      _voteResultTimer?.cancel();
      _voteResultTimer = null;
      _pendingElimination = false;
      _holdingImpostorResult = false;
      _impostorResultTimer?.cancel();
      _impostorResultTimer = null;
    }
  }

  @override
  void dispose() {
    _voteResultTimer?.cancel();
    _impostorResultTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pausedAt = DateTime.now();
      _setConnected(false);
    } else if (state == AppLifecycleState.resumed) {
      _setConnected(true);
      ref.invalidate(myMatchStateProvider(widget.matchId));
      ref.invalidate(onlineMatchProvider(widget.matchId));
      // Only show reconnecting banner if actually backgrounded for >1 second
      final wasPausedAt = _pausedAt;
      _pausedAt = null;
      if (wasPausedAt != null &&
          DateTime.now().difference(wasPausedAt).inMilliseconds > 1000) {
        if (mounted) setState(() => _isReconnecting = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isReconnecting = false);
        });
      }
    }
  }

  void _setConnected(bool connected) {
    final roomId = _roomId;
    if (roomId == null) return;
    ref
        .read(onlineRoomsRepositoryProvider)
        .setPlayerConnected(roomId: roomId, connected: connected)
        .catchError((_) {});
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

    // Cache roomId for lifecycle callbacks & start heartbeat
    final myState = myStateAsync.value;
    if (myState != null && _roomId == null) {
      _roomId = myState.roomId;
    }
    if (_roomId != null) {
      ref.watch(matchHeartbeatProvider((roomId: _roomId!)));
    }

    // Auto-detect if role was already confirmed (reconnection scenario)
    if (myState != null && myState.myRoleConfirmed && !_roleConfirmed) {
      _roleConfirmed = true;
    }

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
          // Catch fast vote_result → next transitions (Realtime may skip rendering vote_result)
          if (prevMatch.currentPhase == OnlineMatchPhase.voteResult &&
              nextMatch.currentPhase != OnlineMatchPhase.voteResult &&
              !_holdingVoteResult) {
            _holdingVoteResult = true;
            _heldVoteResultState = myStateAsync.value;
            _voteResultTimer?.cancel();
            _voteResultTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _holdingVoteResult = false;
                  _heldVoteResultState = null;
                });
                if (_pendingElimination) {
                  _pendingElimination = false;
                  _showEliminatedAndLeave();
                }
              }
            });
          }

          // Impostor choice/guess → next phase: show intermediate screen
          _detectImpostorTransition(prevMatch, nextMatch);

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
          // If vote_result is being held, wait for the hold to finish
          if (_holdingVoteResult) {
            _pendingElimination = true;
          } else {
            _showEliminatedAndLeave();
          }
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
            style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            ConnectionStatusBanner(isReconnecting: _isReconnecting),
            // Spectator banner for eliminated players (not during impostor's decision phases)
            if (myState != null &&
                myState.myIsEliminated &&
                myState.currentPhase != OnlineMatchPhase.impostorChoice &&
                myState.currentPhase != OnlineMatchPhase.impostorGuess &&
                myState.currentPhase != OnlineMatchPhase.finished)
              const SpectatorBanner(),
            Expanded(
              child: myStateAsync.when(
                loading: () => Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
                error: (e, _) => _buildError(e.toString()),
                data: (myState) {
                  // If match is cancelled, show cancelled UI
                  final match = matchAsync.value;
                  if (match != null &&
                      match.status == OnlineMatchStatus.cancelled) {
                    return _buildCancelled();
                  }
                  // All players (including eliminated spectators) go through
                  // _buildMatchContent — phase widgets handle isSpectator
                  return _buildMatchContent(myState);
                },
              ),
            ),
          ],
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
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Si sales ahora seras eliminado de la partida. Si no quedan suficientes jugadores, la partida se cancelara.',
          style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
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
    setState(() {
      _confirmingRole = true;
      _roleConfirmed = true; // Optimistic — prevents flicker on rebuild
    });
    try {
      await ref
          .read(onlineMatchRepositoryProvider)
          .confirmRoleReveal(widget.matchId);
    } catch (e) {
      if (mounted) {
        setState(() => _roleConfirmed = false); // Revert on error
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

  // ─── Impostor transition detection ──────────────────────────────────

  void _detectImpostorTransition(OnlineMatch prevMatch, OnlineMatch nextMatch) {
    if (_holdingImpostorResult) return;

    final prevPhase = prevMatch.currentPhase;
    final nextPhase = nextMatch.currentPhase;

    // impostor_choice → impostor_guess = decided to risk
    if (prevPhase == OnlineMatchPhase.impostorChoice &&
        nextPhase == OnlineMatchPhase.impostorGuess) {
      _findImpostorName();
      _startImpostorHold('risk', 3);
      return;
    }

    // impostor_choice → clue_writing or finished = decided NOT to risk
    if (prevPhase == OnlineMatchPhase.impostorChoice &&
        (nextPhase == OnlineMatchPhase.clueWriting ||
            nextPhase == OnlineMatchPhase.finished)) {
      _findImpostorName();
      _startImpostorHold('no_risk', 3);
      return;
    }

    // impostor_guess → clue_writing or finished = guessed wrong
    // (If guess was correct, match goes to finished with impostors winning —
    //  but skip also goes to clue_writing/finished. We show wrong_guess for
    //  any impostor_guess → non-finished transition, and for finished when
    //  civils win. If impostors win from guess, go straight to results.)
    if (prevPhase == OnlineMatchPhase.impostorGuess &&
        nextPhase != OnlineMatchPhase.impostorGuess) {
      // If impostors won → skip intermediate, go to results
      if (nextPhase == OnlineMatchPhase.finished &&
          nextMatch.status == OnlineMatchStatus.finished) {
        // Check if impostors won — we'll need to load this from match state.
        // For now, we can infer: if match finished from impostor_guess,
        // and winner_override is not set, we need to check.
        // Simplification: always show wrong_guess unless the phase goes to finished
        // AND state says impostors won. We'll let the results screen handle the win.
        // Actually the simplest: fetch guess_word from players to show it.
        // But we can't easily know winner here. Let's always show wrong_guess
        // for impostor_guess → finished where civils win, and skip for impostor win.
        // Since we can't easily determine winner in the listener, let's just
        // not hold when going to finished — the results screen will tell the story.
        return;
      }
      _findImpostorName();
      _findImpostorGuessWord();
      _startImpostorHold('wrong_guess', 4);
      return;
    }
  }

  void _findImpostorName() {
    final players =
        ref.read(onlineMatchPlayersProvider(widget.matchId)).value ?? [];
    final impostor = players
        .where((p) => p.isImpostor && p.isEliminated)
        .lastOrNull;
    _impostorName = impostor?.displayName ?? 'Impostor';
  }

  void _findImpostorGuessWord() {
    final players =
        ref.read(onlineMatchPlayersProvider(widget.matchId)).value ?? [];
    final impostor = players
        .where((p) => p.isImpostor && p.isEliminated)
        .lastOrNull;
    _impostorGuessWord = impostor?.guessWord;
  }

  void _startImpostorHold(String type, int seconds) {
    setState(() {
      _holdingImpostorResult = true;
      _impostorResultType = type;
      _impostorHoldDuration = seconds;
    });
    _impostorResultTimer?.cancel();
    _impostorResultTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          _holdingImpostorResult = false;
          _impostorResultType = null;
          _impostorGuessWord = null;
        });
      }
    });
  }

  // ─── Match content ─────────────────────────────────────────────────

  Widget _buildMatchContent(MyMatchState myState) {
    final phase = myState.currentPhase;

    // When entering vote_result, hold it for 3 seconds
    if (phase == OnlineMatchPhase.voteResult && !_holdingVoteResult) {
      _holdingVoteResult = true;
      _heldVoteResultState = myState;
      _voteResultTimer?.cancel();
      _voteResultTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _holdingVoteResult = false;
            _heldVoteResultState = null;
          });
          if (_pendingElimination) {
            _pendingElimination = false;
            _showEliminatedAndLeave();
          }
        }
      });
    }

    // Keep showing vote_result until hold expires
    if (_holdingVoteResult && phase != OnlineMatchPhase.voteResult) {
      return _buildVoteResult(_heldVoteResultState ?? myState);
    }

    // Show impostor result intermediate screen
    if (_holdingImpostorResult && _impostorResultType != null) {
      return ImpostorResultHold(
        key: ValueKey('impostor_hold_$_impostorResultType'),
        type: _impostorResultType!,
        impostorName: _impostorName ?? 'Impostor',
        guessWord: _impostorGuessWord,
        durationSeconds: _impostorHoldDuration,
      );
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
      case OnlineMatchPhase.impostorChoice:
        return _buildImpostorChoice(myState);
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
      isSpectator: myState.myIsEliminated,
    );
  }

  Widget _buildVoting(MyMatchState myState) {
    return VotingPhase(
      matchId: widget.matchId,
      myState: myState,
      isSpectator: myState.myIsEliminated,
    );
  }

  Widget _buildVoteResult(MyMatchState myState) {
    return VoteResultPhase(
      matchId: widget.matchId,
      myState: myState,
      isSpectator: myState.myIsEliminated,
    );
  }

  Widget _buildImpostorChoice(MyMatchState myState) {
    return ImpostorChoicePhase(
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
    return RoleRevealPhase(
      matchId: widget.matchId,
      myState: myState,
      skipAnimation: _roleConfirmed || myState.myRoleConfirmed,
      roleConfirmed: _roleConfirmed,
      confirmingRole: _confirmingRole,
      onConfirmRole: _handleConfirmRole,
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
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No quedaron suficientes jugadores para continuar la partida.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
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
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
