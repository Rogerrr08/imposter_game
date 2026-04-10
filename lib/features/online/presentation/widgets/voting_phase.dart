import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';
import '../../domain/online_match.dart';

class VotingPhase extends ConsumerStatefulWidget {
  final String matchId;
  final MyMatchState myState;
  final bool isSpectator;

  const VotingPhase({
    super.key,
    required this.matchId,
    required this.myState,
    this.isSpectator = false,
  });

  @override
  ConsumerState<VotingPhase> createState() => _VotingPhaseState();
}

class _VotingPhaseState extends ConsumerState<VotingPhase> {
  String? _selectedTargetId;
  bool _submitting = false;
  bool _hasVoted = false;

  @override
  void didUpdateWidget(VotingPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset vote state when re-entering voting phase (e.g., after tiebreak)
    if (oldWidget.myState.currentPhase != widget.myState.currentPhase ||
        oldWidget.myState.stateVersion != widget.myState.stateVersion) {
      _hasVoted = false;
      _selectedTargetId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(onlineMatchPlayersProvider(widget.matchId));
    final votesAsync = ref.watch(onlineMatchVotesProvider(widget.matchId));
    final cluesAsync = ref.watch(onlineMatchCluesProvider(widget.matchId));
    final matchAsync = ref.watch(onlineMatchProvider(widget.matchId));

    final players = playersAsync.value ?? [];
    final votes = votesAsync.value ?? [];
    final clues = cluesAsync.value ?? [];
    final match = matchAsync.value;
    final currentRound = match?.currentRound ?? widget.myState.currentRound;

    final activePlayers = players.where((p) => !p.isEliminated).toList();
    final roundVotes = votes
        .where((v) => v.roundNumber == currentRound)
        .toList();

    // Check if there's a tiebreak in progress
    final tiebreakVotes = roundVotes.where((v) => v.isTiebreak).toList();
    final isTiebreak = tiebreakVotes.isNotEmpty ||
        // If we're back in voting after a vote_result with tie, it's tiebreak
        roundVotes.where((v) => !v.isTiebreak).length >= activePlayers.length;

    final relevantVotes =
        isTiebreak ? tiebreakVotes : roundVotes.where((v) => !v.isTiebreak).toList();

    // Did current player already vote?
    final myVote = relevantVotes
        .where((v) => v.voterId == widget.myState.myPlayerId)
        .firstOrNull;
    if (myVote != null && !_hasVoted) {
      _hasVoted = true;
    }
    // Spectators always see the waiting/status view
    if (widget.isSpectator && !_hasVoted) {
      _hasVoted = true;
    }

    final votedPlayerIds =
        relevantVotes.map((v) => v.voterId).toSet();
    final votedCount = votedPlayerIds.length;
    final totalActive = activePlayers.length;

    // In tiebreak: determine which players were tied from the first-round votes
    Set<String>? tiedPlayerIds;
    if (isTiebreak) {
      final firstRoundVotes =
          roundVotes.where((v) => !v.isTiebreak).toList();
      final votesByTarget = <String, int>{};
      for (final v in firstRoundVotes) {
        votesByTarget[v.targetPlayerId] =
            (votesByTarget[v.targetPlayerId] ?? 0) + 1;
      }
      if (votesByTarget.isNotEmpty) {
        final maxVotes =
            votesByTarget.values.reduce((a, b) => a > b ? a : b);
        tiedPlayerIds = votesByTarget.entries
            .where((e) => e.value == maxVotes)
            .map((e) => e.key)
            .toSet();
      }
    }

    // Votable players: active, not self, (in tiebreak: only tied candidates)
    final votablePlayers = activePlayers.where((p) {
      if (p.id == widget.myState.myPlayerId) return false;
      if (isTiebreak && tiedPlayerIds != null) {
        return tiedPlayerIds.contains(p.id);
      }
      return true;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          // Header
          _buildVoteHeader(votedCount, totalActive, isTiebreak),

          // Clue reference (collapsible)
          if (clues.isNotEmpty)
            _buildClueReference(clues, players, currentRound),

          // Voting grid or waiting state
          Expanded(
            child: _hasVoted
                ? _buildWaitingForOthers(
                    myVote, players, votedPlayerIds, activePlayers)
                : _buildVotingGrid(votablePlayers),
          ),

          // Submit button
          if (!_hasVoted) _buildSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildVoteHeader(int votedCount, int totalActive, bool isTiebreak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: Text(
              isTiebreak
                  ? 'Desempate — vota de nuevo'
                  : 'Votación — elige al sospechoso',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.warningColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$votedCount/$totalActive',
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClueReference(
      List<OnlineMatchClue> clues, List<OnlineMatchPlayer> players, int currentRound) {
    final roundClues =
        clues.where((c) => c.roundNumber == currentRound).toList();
    if (roundClues.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        'Pistas de esta ronda (${roundClues.length})',
        style: TextStyle(fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: roundClues.map((clue) {
              final player =
                  players.where((p) => p.id == clue.playerId).firstOrNull;
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(
                    (player?.displayName ?? '?').characters.first.toUpperCase(),
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                label: Text(
                  clue.clue,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildVotingGrid(List<OnlineMatchPlayer> votablePlayers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: votablePlayers.length,
      itemBuilder: (context, index) {
        final player = votablePlayers[index];
        final isSelected = _selectedTargetId == player.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedTargetId = player.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.secondaryColor.withValues(alpha: 0.12)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.secondaryColor
                    : AppTheme.textSecondary.withValues(alpha: 0.08),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isSelected
                            ? AppTheme.secondaryColor
                            : AppTheme.primaryColor)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      player.displayName.characters.first.toUpperCase(),
                      style: TextStyle(fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppTheme.secondaryColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            player.displayName,
                            style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (widget.myState.myIsEliminated ||
                              widget.myState.isSpectator) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: player.role == 'impostor'
                                    ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                                    : AppTheme.successColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                player.role == 'impostor' ? 'Impostor' : 'Civil',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: player.role == 'impostor'
                                      ? AppTheme.secondaryColor
                                      : AppTheme.successColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!player.isConnected)
                        Text(
                          '(desconectado)',
                          style: TextStyle(fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingForOthers(
    OnlineMatchVote? myVote,
    List<OnlineMatchPlayer> players,
    Set<String> votedPlayerIds,
    List<OnlineMatchPlayer> activePlayers,
  ) {
    final myTarget =
        players.where((p) => p.id == myVote?.targetPlayerId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // My vote summary (only if player actually voted)
          if (myVote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.how_to_vote_rounded,
                      color: AppTheme.secondaryColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Votaste por ',
                        style: TextStyle(fontFamily: 'Nunito',
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: myTarget?.displayName ?? '...',
                            style: TextStyle(fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Player vote status list
          Expanded(
            child: ListView.builder(
              itemCount: activePlayers.length,
              itemBuilder: (context, index) {
                final player = activePlayers[index];
                final hasVoted = votedPlayerIds.contains(player.id);
                final isMe = player.id == widget.myState.myPlayerId;

                final isDisconnected = !player.isConnected;
                final statusColor = hasVoted
                    ? AppTheme.successColor
                    : isDisconnected
                        ? AppTheme.warningColor
                        : AppTheme.textSecondary;
                final statusText = hasVoted
                    ? 'Voto'
                    : isDisconnected
                        ? 'Desconectado'
                        : 'Esperando...';
                final statusIcon = hasVoted
                    ? Icons.check_rounded
                    : isDisconnected
                        ? Icons.wifi_off_rounded
                        : Icons.hourglass_top_rounded;

                final tile = ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 18, color: statusColor),
                  ),
                  title: Text(
                    '${player.displayName}${isMe ? ' (Tu)' : ''}',
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDisconnected && !hasVoted
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: Text(
                    statusText,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                );

                if (isDisconnected && !hasVoted) {
                  return Opacity(opacity: 0.55, child: tile);
                }
                return tile;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedTargetId != null && !_submitting
              ? _handleSubmitVote
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  _selectedTargetId != null
                      ? 'Confirmar voto'
                      : 'Selecciona un jugador',
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleSubmitVote() async {
    if (_selectedTargetId == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onlineMatchRepositoryProvider).submitVote(
            matchId: widget.matchId,
            targetPlayerId: _selectedTargetId!,
          );
      if (mounted) {
        setState(() {
          _hasVoted = true;
          _submitting = false;
        });
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
