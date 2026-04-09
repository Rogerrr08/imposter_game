import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';

class VoteResultPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;
  final bool isSpectator;

  const VoteResultPhase({
    super.key,
    required this.matchId,
    required this.myState,
    this.isSpectator = false,
  });

  @override
  ConsumerState<VoteResultPhase> createState() => _VoteResultPhaseState();
}

class _VoteResultPhaseState extends ConsumerState<VoteResultPhase>
    with SingleTickerProviderStateMixin {
  VoteResolutionResult? _resolution;
  bool _resolving = false;
  bool _resolved = false;

  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _resolveVotes();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _resolveVotes() async {
    if (_resolving || _resolved) return;
    setState(() => _resolving = true);

    try {
      final result = await ref
          .read(onlineMatchRepositoryProvider)
          .resolveVotes(widget.matchId);
      if (mounted) {
        setState(() {
          _resolution = result;
          _resolved = true;
          _resolving = false;
        });
        // Start the 3-second countdown bar
        _timerController.forward();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() => _resolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final votesAsync = ref.watch(onlineMatchVotesProvider(widget.matchId));

    final players = playersAsync.value ?? [];
    final votes = votesAsync.value ?? [];
    final currentRound = widget.myState.currentRound;

    if (_resolving || !_resolved) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              'Contando votos...',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final resolution = _resolution!;

    // Show votes breakdown
    final roundVotes =
        votes.where((v) => v.roundNumber == currentRound).toList();

    return SafeArea(
      child: Column(
        children: [
          // Depleting timer bar at the top
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _timerController.value,
                backgroundColor:
                    AppTheme.textSecondary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  resolution.isTie
                      ? AppTheme.warningColor
                      : resolution.isGameOver
                          ? (resolution.winner == 'civils'
                              ? AppTheme.successColor
                              : AppTheme.secondaryColor)
                          : AppTheme.primaryColor,
                ),
                minHeight: 4,
              );
            },
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Title
                  Text(
                    'Resultado de la votacion',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Votes breakdown
                  _buildVotesBreakdown(roundVotes, players),
                  const SizedBox(height: 20),

                  // Resolution result
                  _buildResolutionCard(resolution, players),
                  const SizedBox(height: 24),

                  // Info text about what happens next
                  _buildNextPhaseInfo(resolution),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotesBreakdown(
      List<OnlineMatchVote> votes, List<OnlineMatchPlayer> players) {
    // Group votes by target
    final votesByTarget = <String, List<OnlineMatchVote>>{};
    for (final vote in votes) {
      votesByTarget.putIfAbsent(vote.targetPlayerId, () => []).add(vote);
    }

    // Sort by vote count descending
    final sortedTargets = votesByTarget.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votos',
          style: TextStyle(fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedTargets.map((entry) {
          final target = players.where((p) => p.id == entry.key).firstOrNull;
          final voteCount = entry.value.length;
          final voters = entry.value
              .map((v) =>
                  players
                      .where((p) => p.id == v.voterId)
                      .firstOrNull
                      ?.displayName ??
                  '?')
              .toList();

          final isEliminated = _resolution?.eliminatedPlayerId == entry.key;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEliminated
                  ? AppTheme.secondaryColor.withValues(alpha: 0.1)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEliminated
                    ? AppTheme.secondaryColor.withValues(alpha: 0.4)
                    : AppTheme.textSecondary.withValues(alpha: 0.08),
                width: isEliminated ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$voteCount',
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target?.displayName ?? '?',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Votaron: ${voters.join(', ')}',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEliminated)
                  Icon(Icons.close_rounded,
                      color: AppTheme.secondaryColor, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResolutionCard(
      VoteResolutionResult resolution, List<OnlineMatchPlayer> players) {
    final viewerIsImpostor = widget.myState.isImpostor;

    if (resolution.isTie) {
      final tiedNames = resolution.tiedPlayerIds
              ?.map((id) =>
                  players.where((p) => p.id == id).firstOrNull?.displayName ??
                  '?')
              .toList() ??
          [];

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/images/tie_after_voting.webp',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 16),
            Text(
              'Empate!',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Empataron: ${tiedNames.join(' y ')}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Se hara una ronda de desempate.',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Someone was eliminated
    final eliminatedPlayer =
        players.where((p) => p.id == resolution.eliminatedPlayerId).firstOrNull;
    final isImpostor = resolution.eliminatedRole == 'impostor';
    final roleColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: roleColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Image.asset(
            isImpostor
                ? (viewerIsImpostor
                    ? 'assets/images/impostor_failed_guess.webp'
                    : 'assets/images/civil_correct_guess.webp')
                : (viewerIsImpostor
                    ? 'assets/images/impostor_correct_guess.webp'
                    : 'assets/images/civil_lose_life.webp'),
            width: 140,
            height: 140,
          ),
          const SizedBox(height: 16),
          Text(
            '${eliminatedPlayer?.displayName ?? '?'} fue eliminado',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isImpostor ? 'Era Impostor!' : 'Era Civil',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: roleColor,
              ),
            ),
          ),
          if (resolution.isGameOver) ...[
            const SizedBox(height: 16),
            Text(
              resolution.winner == 'civils'
                  ? 'Los civiles ganan!'
                  : 'Los impostores ganan!',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: resolution.winner == 'civils'
                    ? AppTheme.successColor
                    : AppTheme.secondaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextPhaseInfo(VoteResolutionResult resolution) {
    final text = resolution.isTie
        ? 'La votacion de desempate comenzara en unos segundos...'
        : resolution.isGameOver
            ? 'La partida ha terminado.'
            : resolution.isImpostorEliminated
                ? 'Los impostores restantes pueden intentar adivinar la palabra...'
                : 'Siguiente ronda de pistas en unos segundos...';

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Nunito',
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
