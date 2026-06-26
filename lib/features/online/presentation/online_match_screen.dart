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
import 'widgets/reveal_countdown.dart';
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
  bool _isLateJoinSpectator = false;
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

  // Hold clue_writing screen before voting (5s countdown)
  bool _holdingPreVote = false;
  int _preVoteCountdown = 5;
  Timer? _preVoteTimer;

  // Reveal countdown before vote_result or finished
  bool _showingRevealCountdown = false;
  String? _revealTarget; // 'vote_result' or 'finished'

  // Hold impostor result intermediate screen
  bool _holdingImpostorResult = false;
  String? _impostorResultType; // 'risk', 'no_risk', 'wrong_guess'
  String? _impostorName;
  String? _impostorAvatarUrl;
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
      _holdingPreVote = false;
      _preVoteTimer?.cancel();
      _preVoteTimer = null;
      _showingRevealCountdown = false;
      _revealTarget = null;
      _isLateJoinSpectator = false;
    }
  }

  @override
  void dispose() {
    _voteResultTimer?.cancel();
    _impostorResultTimer?.cancel();
    _preVoteTimer?.cancel();
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
      // Reconciliar tras posible muerte silenciosa del socket en segundo
      // plano: recarga el snapshot por HTTPS y recrea el canal para forzar
      // la reconexión del WebSocket. Reemplaza al viejo invalidate del
      // provider (que solo re-leía el estado cacheado en memoria sin tocar
      // el socket ni recargar el snapshot).
      unawaited(ref.read(onlineMatchChannelProvider(widget.matchId)).resync());
      ref.invalidate(myMatchStateProvider(widget.matchId));
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

    // Detect spectator mode: myMatchState errors but match exists (late joiner)
    final match = matchAsync.value;
    if (myStateAsync.hasError && match != null && !_isLateJoinSpectator) {
      _isLateJoinSpectator = true;
    }

    // Fuente única de verdad (Fase 1): la identidad inmutable (rol/palabra/
    // pista/seat) viene del RPC una sola vez; el PROGRESO vivo (fase/turno/
    // ronda/eliminado/puntos) sale SIEMPRE de los streams del canal realtime.
    // Construimos un MyMatchState "efectivo" mezclando ambos, así las pantallas
    // no cambian de firma pero nunca renderizan una fase/turno viejos del RPC.
    final identity = myStateAsync.value;
    final players =
        ref.watch(onlineMatchPlayersProvider(widget.matchId)).value ??
        const <OnlineMatchPlayer>[];

    MyMatchState? myState;
    if (_isLateJoinSpectator && match != null) {
      myState = MyMatchState.spectator(match);
    } else if (identity != null && match != null) {
      // Mi jugador vivo (eliminado/puntos/rol confirmado) del stream.
      final mine = players
          .where((p) => p.id == identity.myPlayerId)
          .firstOrNull;
      final eliminated = mine?.isEliminated ?? identity.myIsEliminated;
      myState = MyMatchState(
        matchId: identity.matchId,
        roomId: identity.roomId,
        status: match.status,
        category: identity.category,
        hintsEnabled: identity.hintsEnabled,
        impostorCount: identity.impostorCount,
        durationSeconds: identity.durationSeconds,
        // Progreso: SIEMPRE del stream del match.
        currentPhase: match.currentPhase,
        currentRound: match.currentRound,
        currentTurnIndex: match.currentTurnIndex,
        stateVersion: match.stateVersion,
        // Identidad: inmutable, del RPC.
        myPlayerId: identity.myPlayerId,
        myRole: identity.myRole,
        myHint: identity.myHint,
        mySeatOrder: identity.mySeatOrder,
        // Estado vivo: del stream de jugadores.
        myIsEliminated: eliminated,
        myPoints: mine?.points ?? identity.myPoints,
        myRoleConfirmed: mine?.roleConfirmed ?? identity.myRoleConfirmed,
        // El impostor ve la palabra recién al ser eliminado.
        word: identity.word ?? (eliminated ? match.word : null),
      );
    } else {
      // Streams aún cargando: usar el snapshot del RPC como respaldo inicial.
      myState = identity;
    }

    // Cache roomId for lifecycle callbacks & start heartbeat
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
    ref.listen<AsyncValue<OnlineMatch?>>(onlineMatchProvider(widget.matchId), (
      prev,
      next,
    ) {
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
          _heldVoteResultState = _isLateJoinSpectator
              ? MyMatchState.spectator(prevMatch)
              : myState;
          _voteResultTimer?.cancel();
          _voteResultTimer = Timer(const Duration(seconds: 5), () {
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

        // Reset reveal countdown target when entering a new round
        if (nextMatch.currentPhase == OnlineMatchPhase.clueWriting ||
            nextMatch.currentPhase == OnlineMatchPhase.voting) {
          _revealTarget = null;
        }

        // Catch clue_writing → voting: hold clues for 5s countdown
        if (prevMatch.currentPhase == OnlineMatchPhase.clueWriting &&
            nextMatch.currentPhase == OnlineMatchPhase.voting &&
            !_holdingPreVote) {
          _startPreVoteCountdown();
        }

        // Impostor choice/guess → next phase: show intermediate screen
        _detectImpostorTransition(prevMatch, nextMatch);
      }
    });

    // Listen for other players leaving (show snackbar notification)
    ref.listen<AsyncValue<List<OnlineMatchPlayer>>>(
      onlineMatchPlayersProvider(widget.matchId),
      (prev, next) {
        final prevPlayers = prev?.value;
        final nextPlayers = next.value;
        if (prevPlayers == null || nextPlayers == null) return;

        // Find players who were active before but are now eliminated
        // Only show "left" notification if it's not a vote elimination
        final currentPhase = match?.currentPhase;
        final isVoteElimination =
            currentPhase == OnlineMatchPhase.voteResult ||
            currentPhase == OnlineMatchPhase.impostorChoice ||
            currentPhase == OnlineMatchPhase.impostorGuess;
        if (!isVoteElimination) {
          for (final prevPlayer in prevPlayers) {
            if (prevPlayer.isEliminated) continue;
            // Skip self
            if (!_isLateJoinSpectator &&
                myState != null &&
                prevPlayer.id == myState.myPlayerId) {
              continue;
            }
            final nextPlayer = nextPlayers
                .where((p) => p.id == prevPlayer.id)
                .firstOrNull;
            if (nextPlayer != null && nextPlayer.isEliminated) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${prevPlayer.displayName} salió de la partida',
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(
                      bottom: 80,
                      left: 16,
                      right: 16,
                    ),
                  ),
                );
              }
            }
          }
        }
      },
    );

    // Listen for self-elimination (voto, otro dispositivo, o server-side).
    // Antes se detectaba invalidando el RPC; ahora sale del stream de jugadores
    // (fuente única de verdad), buscando mi propio jugador por id.
    if (!_isLateJoinSpectator && myState != null) {
      final myId = myState.myPlayerId;
      ref.listen<AsyncValue<List<OnlineMatchPlayer>>>(
        onlineMatchPlayersProvider(widget.matchId),
        (prev, next) {
          final prevMine = prev?.value
              ?.where((p) => p.id == myId)
              .firstOrNull;
          final nextMine = next.value
              ?.where((p) => p.id == myId)
              .firstOrNull;
          if (prevMine != null &&
              nextMine != null &&
              !prevMine.isEliminated &&
              nextMine.isEliminated) {
            if (_holdingVoteResult) {
              _pendingElimination = true;
            } else {
              _showEliminatedAndLeave();
            }
          }
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _confirmLeave,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Salir de la partida',
          ),
          title: const Text(
            'Partida online',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: Column(
          children: [
            ConnectionStatusBanner(isReconnecting: _isReconnecting),
            // Spectator banner for eliminated players or late joiners
            if (myState != null &&
                (myState.isSpectator || myState.myIsEliminated) &&
                myState.currentPhase != OnlineMatchPhase.impostorChoice &&
                myState.currentPhase != OnlineMatchPhase.impostorGuess &&
                myState.currentPhase != OnlineMatchPhase.finished)
              SpectatorBanner(
                label: _isLateJoinSpectator ? 'Espectando partida' : null,
              ),
            Expanded(
              child: _isLateJoinSpectator && myState != null
                  ? _buildSpectatorContent(myState)
                  : myState == null
                  // Identidad aún cargando (o error): respaldo loading/error.
                  ? (myStateAsync.hasError
                        ? _buildError(myStateAsync.error.toString())
                        : Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ))
                  : (match != null &&
                        match.status == OnlineMatchStatus.cancelled)
                  ? _buildCancelled()
                  : _buildMatchContent(myState),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    // Late join spectators can leave without confirmation
    if (_isLateJoinSpectator && mounted) {
      context.go(_roomId != null ? '/online/room/$_roomId' : '/online');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Salir de la partida',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Si sales ahora serás eliminado de la partida. Si no quedan suficientes jugadores, la partida se cancelará.',
          style: TextStyle(color: AppTheme.textSecondary),
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
      context.go(_roomId != null ? '/online/room/$_roomId' : '/online');
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
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingRole = false);
    }
  }

  // ─── Pre-vote countdown ─────────────────────────────────────────────

  void _startPreVoteCountdown() {
    setState(() {
      _holdingPreVote = true;
      _preVoteCountdown = 5;
    });
    _preVoteTimer?.cancel();
    _preVoteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _preVoteCountdown--);
      if (_preVoteCountdown <= 0) {
        timer.cancel();
        setState(() => _holdingPreVote = false);
      }
    });
  }

  // ─── Impostor transition detection ──────────────────────────────────

  void _detectImpostorTransition(OnlineMatch prevMatch, OnlineMatch nextMatch) {
    if (_holdingImpostorResult) return;

    final prevPhase = prevMatch.currentPhase;
    final nextPhase = nextMatch.currentPhase;

    // impostor_choice → impostor_guess = decided to risk
    if (prevPhase == OnlineMatchPhase.impostorChoice &&
        nextPhase == OnlineMatchPhase.impostorGuess) {
      _captureImpostorInfo();
      _startImpostorHold('risk', 3);
      return;
    }

    // impostor_choice → clue_writing or finished = decided NOT to risk
    if (prevPhase == OnlineMatchPhase.impostorChoice &&
        (nextPhase == OnlineMatchPhase.clueWriting ||
            nextPhase == OnlineMatchPhase.finished)) {
      _captureImpostorInfo();
      _startImpostorHold('no_risk', 3);
      return;
    }

    // impostor_guess → otra fase: el impostor adivinó (bien o mal).
    // Inferimos el resultado SIN tocar SQL: el RPC marca
    // `eliminated_by_failed_guess = true` solo en adivinanza incorrecta. Si el
    // adivinador tiene `guessWord` y NO ese flag, acertó (los impostores ganan).
    if (prevPhase == OnlineMatchPhase.impostorGuess &&
        nextPhase != OnlineMatchPhase.impostorGuess) {
      final guesser = _findImpostorGuesser();
      final guessedCorrectly = guesser != null &&
          guesser.guessWord != null &&
          !guesser.eliminatedByFailedGuess;

      _captureImpostorInfo(guesser);

      if (guessedCorrectly) {
        // Cierra el arco: celebración antes de los resultados finales.
        _startImpostorHold('correct_guess', 4);
      } else if (nextPhase == OnlineMatchPhase.finished &&
          nextMatch.status == OnlineMatchStatus.finished) {
        // Adivinó mal y se acabó (civiles ganan): la pantalla de resultados
        // cuenta la historia, no holdeamos.
        return;
      } else {
        _startImpostorHold('wrong_guess', 4);
      }
      return;
    }
  }

  /// El impostor eliminado que adivinó (último impostor eliminado).
  OnlineMatchPlayer? _findImpostorGuesser() {
    final players =
        ref.read(onlineMatchPlayersProvider(widget.matchId)).value ?? [];
    return players
        .where((p) => p.isImpostor && p.isEliminated)
        .lastOrNull;
  }

  /// Captura nombre/avatar/palabra del impostor que adivinó para el hold.
  void _captureImpostorInfo([OnlineMatchPlayer? guesser]) {
    final impostor = guesser ?? _findImpostorGuesser();
    _impostorName = impostor?.displayName ?? 'Impostor';
    _impostorAvatarUrl = impostor?.avatarUrl;
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

    // Show reveal countdown before vote_result
    if (phase == OnlineMatchPhase.voteResult &&
        !_holdingVoteResult &&
        !_showingRevealCountdown &&
        _revealTarget != 'vote_result_done') {
      _showingRevealCountdown = true;
      _revealTarget = 'vote_result';
    }

    // Show reveal countdown before finished (final results).
    // Si estamos holdeando el resultado del impostor (p.ej. adivinó correcto),
    // ese hold va primero; el countdown se dispara al terminar.
    if (phase == OnlineMatchPhase.finished &&
        !_showingRevealCountdown &&
        !_holdingImpostorResult &&
        _revealTarget != 'finished_done') {
      _showingRevealCountdown = true;
      _revealTarget = 'finished';
    }

    // Render the reveal countdown
    if (_showingRevealCountdown) {
      return RevealCountdown(
        key: ValueKey('reveal_$_revealTarget'),
        durationSeconds: 3,
        onComplete: () {
          if (mounted) {
            setState(() {
              _showingRevealCountdown = false;
              // Mark as done so we don't re-trigger
              if (_revealTarget == 'vote_result') {
                _revealTarget = 'vote_result_done';
                // Start the vote_result hold timer
                _holdingVoteResult = true;
                _heldVoteResultState = myState;
                _voteResultTimer?.cancel();
                _voteResultTimer = Timer(const Duration(seconds: 5), () {
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
              } else if (_revealTarget == 'finished') {
                _revealTarget = 'finished_done';
              }
            });
          }
        },
      );
    }

    // When entering vote_result (after countdown), hold it for 5 seconds
    if (phase == OnlineMatchPhase.voteResult &&
        !_holdingVoteResult &&
        _revealTarget == 'vote_result_done') {
      _holdingVoteResult = true;
      _heldVoteResultState = myState;
      _voteResultTimer?.cancel();
      _voteResultTimer = Timer(const Duration(seconds: 5), () {
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
        impostorAvatarUrl: _impostorAvatarUrl,
        guessWord: _impostorGuessWord,
        durationSeconds: _impostorHoldDuration,
      );
    }

    // Hold clue_writing screen with countdown before showing voting
    if (_holdingPreVote && phase == OnlineMatchPhase.voting) {
      return _buildClueWritingWithCountdown(myState);
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

  Widget _buildSpectatorContent(MyMatchState myState) {
    final phase = myState.currentPhase;

    // Reveal countdown for spectators too
    if (_showingRevealCountdown) {
      return RevealCountdown(
        key: ValueKey('reveal_spectator_$_revealTarget'),
        durationSeconds: 3,
        onComplete: () {
          if (mounted) {
            setState(() {
              _showingRevealCountdown = false;
              if (_revealTarget == 'vote_result') {
                _revealTarget = 'vote_result_done';
                _holdingVoteResult = true;
                _heldVoteResultState = myState;
                _voteResultTimer?.cancel();
                _voteResultTimer = Timer(const Duration(seconds: 5), () {
                  if (mounted) {
                    setState(() {
                      _holdingVoteResult = false;
                      _heldVoteResultState = null;
                    });
                  }
                });
              } else if (_revealTarget == 'finished') {
                _revealTarget = 'finished_done';
              }
            });
          }
        },
      );
    }

    // Trigger reveal countdown for spectator
    if (phase == OnlineMatchPhase.voteResult &&
        !_holdingVoteResult &&
        !_showingRevealCountdown &&
        _revealTarget != 'vote_result_done') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showingRevealCountdown = true;
            _revealTarget = 'vote_result';
          });
        }
      });
    }
    if (phase == OnlineMatchPhase.finished &&
        !_showingRevealCountdown &&
        !_holdingImpostorResult &&
        _revealTarget != 'finished_done') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showingRevealCountdown = true;
            _revealTarget = 'finished';
          });
        }
      });
    }

    // Hold vote result for spectators too
    if (_holdingVoteResult && phase != OnlineMatchPhase.voteResult) {
      return _buildVoteResult(_heldVoteResultState ?? myState);
    }

    // Hold impostor result
    if (_holdingImpostorResult && _impostorResultType != null) {
      return ImpostorResultHold(
        key: ValueKey('impostor_hold_$_impostorResultType'),
        type: _impostorResultType!,
        impostorName: _impostorName ?? 'Impostor',
        impostorAvatarUrl: _impostorAvatarUrl,
        guessWord: _impostorGuessWord,
        durationSeconds: _impostorHoldDuration,
      );
    }

    // Hold clue_writing screen with countdown
    if (_holdingPreVote && phase == OnlineMatchPhase.voting) {
      return _buildClueWritingWithCountdown(myState);
    }

    switch (phase) {
      case OnlineMatchPhase.roleReveal:
        // Spectators see the clue writing view (waiting for players to confirm roles)
        return ClueWritingPhase(
          matchId: widget.matchId,
          myState: myState,
          isSpectator: true,
        );
      case OnlineMatchPhase.clueWriting:
        return ClueWritingPhase(
          matchId: widget.matchId,
          myState: myState,
          isSpectator: true,
        );
      case OnlineMatchPhase.voting:
        return VotingPhase(
          matchId: widget.matchId,
          myState: myState,
          isSpectator: true,
        );
      case OnlineMatchPhase.voteResult:
        return VoteResultPhase(
          matchId: widget.matchId,
          myState: myState,
          isSpectator: true,
        );
      case OnlineMatchPhase.impostorChoice:
      case OnlineMatchPhase.impostorGuess:
        // Spectators see a waiting message during impostor decision
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/player_impostor.webp',
                  width: 110,
                  height: 110,
                  cacheWidth: 220,
                  cacheHeight: 220,
                ),
                const SizedBox(height: 16),
                Text(
                  'El impostor está tomando una decisión...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      case OnlineMatchPhase.finished:
        return MatchResultsPhase(
          matchId: widget.matchId,
          myState: myState,
          isSpectator: true,
        );
    }
  }

  Widget _buildClueWriting(MyMatchState myState) {
    return ClueWritingPhase(
      matchId: widget.matchId,
      myState: myState,
      isSpectator: myState.myIsEliminated,
    );
  }

  Widget _buildClueWritingWithCountdown(MyMatchState myState) {
    return ClueWritingPhase(
      matchId: widget.matchId,
      myState: myState,
      isSpectator: true, // No input during countdown
      countdownSeconds: _preVoteCountdown,
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
    return ImpostorChoicePhase(matchId: widget.matchId, myState: myState);
  }

  Widget _buildImpostorGuess(MyMatchState myState) {
    return ImpostorGuessPhase(matchId: widget.matchId, myState: myState);
  }

  Widget _buildMatchResults(MyMatchState myState) {
    return MatchResultsPhase(matchId: widget.matchId, myState: myState);
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No quedaron suficientes jugadores para continuar la partida.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go(
                  _roomId != null ? '/online/room/$_roomId' : '/online',
                ),
                child: const Text('Volver a la sala'),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(
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
