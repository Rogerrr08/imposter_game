import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/action_reveal.dart';
import '../../theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';

class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key});

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPlayer;
  String? _votedBy;
  bool _hasVoted = false;
  bool _wasImpostor = false;

  late AnimationController _resultAnimController;
  late Animation<double> _resultScaleAnimation;
  late Animation<double> _resultFadeAnimation;

  @override
  void initState() {
    super.initState();
    _resultAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultScaleAnimation = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.elasticOut,
    );
    _resultFadeAnimation = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    super.dispose();
  }

  void _confirmVote() {
    if (_selectedPlayer == null || _votedBy == null) return;

    final gameState = ref.read(gameProvider);
    if (gameState == null) return;

    GamePlayer? voter;
    for (final player in gameState.activePlayers) {
      if (player.name == _votedBy) {
        voter = player;
        break;
      }
    }

    if (voter == null) return;

    if (voter.role == PlayerRole.impostor) {
      _showVoteError(
        'Los impostores no pueden proponer votos.',
      );
      return;
    }

    if (_selectedPlayer == _votedBy) {
      _showVoteError(
        'Un jugador no puede votarse a si mismo.',
      );
      return;
    }

    final wasImpostor = ref.read(gameProvider.notifier).eliminatePlayer(
      _selectedPlayer!,
      votedBy: _votedBy,
    );

    context.go(
      '/action-reveal',
      extra: ActionRevealData(
        type: ActionRevealType.vote,
        success: wasImpostor,
        subjectText: _selectedPlayer!,
        actorText: _votedBy,
        livesRemaining: wasImpostor ? null : gameState.livesRemaining,
      ),
    );
  }

  void _showVoteError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Voto no valido',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Entendido',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _continue() {
    final gameState = ref.read(gameProvider);
    if (gameState == null) {
      context.go('/');
      return;
    }

    if (gameState.gameOver || gameState.phase == GamePhase.results) {
      context.go('/results');
    } else {
      context.go('/play');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _hasVoted
              ? _buildResultView(gameState)
              : _buildVotingView(gameState),
        ),
      ),
    );
  }

  Widget _buildVotingView(ActiveGame gameState) {
    final activePlayers = gameState.activePlayers;
    final selectedVoterValue = activePlayers.any((player) => player.name == _votedBy)
        ? _votedBy
        : null;

    return Column(
      children: [
        const SizedBox(height: 24),
        // Header
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryColor, width: 2),
          ),
          child: const Icon(
            Icons.how_to_vote_rounded,
            size: 34,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quien es el impostor?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        if (gameState.shouldShowStartingPlayer) ...[
          const SizedBox(height: 12),
          _buildStartingPlayerBanner(gameState.startingPlayerName!),
        ],
        const SizedBox(height: 4),
        // Lives indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < ActiveGame.maxLives; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < gameState.livesRemaining
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: i < gameState.livesRemaining
                      ? AppTheme.secondaryColor
                      : Colors.white24,
                  size: 20,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '${gameState.livesRemaining} vida${gameState.livesRemaining == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: gameState.livesRemaining == 1
                    ? AppTheme.secondaryColor
                    : Colors.white54,
                fontWeight: gameState.livesRemaining == 1
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Who is voting dropdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: Text(
                'Quien propone el voto?',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
              ),
              value: selectedVoterValue,
              dropdownColor: AppTheme.surfaceColor,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              items: activePlayers.map((p) {
                return DropdownMenuItem(
                  value: p.name,
                  child: Text(p.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _votedBy = val),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Player list
        Expanded(
          child: ListView.separated(
            itemCount: activePlayers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final player = activePlayers[index];
              final isSelected = _selectedPlayer == player.name;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedPlayer = player.name);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.secondaryColor
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.secondaryColor.withValues(alpha: 0.3)
                              : AppTheme.primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            player.name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.secondaryColor
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          player.name,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.secondaryColor
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.secondaryColor
                                : Colors.white30,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16,
                                color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _selectedPlayer != null && _votedBy != null ? _confirmVote : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              disabledBackgroundColor:
                  AppTheme.secondaryColor.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Confirmar Voto'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStartingPlayerBanner(String playerName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_arrow_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Empieza: $playerName',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(ActiveGame gameState) {
    final color =
        _wasImpostor ? AppTheme.secondaryColor : AppTheme.successColor;
    final icon = _wasImpostor
        ? Icons.whatshot_rounded
        : Icons.sentiment_dissatisfied_rounded;
    final title = _wasImpostor ? 'Era impostor!' : 'Era inocente!';

    String subtitle;
    if (_wasImpostor) {
      subtitle = 'Buen trabajo, encontraron a un impostor';
    } else {
      subtitle = '${_votedBy ?? 'El civil que voto'} fallo y queda eliminado.\n'
          '${gameState.livesRemaining} vida${gameState.livesRemaining == 1 ? '' : 's'} restante${gameState.livesRemaining == 1 ? '' : 's'}';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        FadeTransition(
          opacity: _resultFadeAnimation,
          child: ScaleTransition(
            scale: _resultScaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 64, color: color),
                ),
                const SizedBox(height: 32),
                Text(
                  _selectedPlayer ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!_wasImpostor) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < ActiveGame.maxLives; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            i < gameState.livesRemaining
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: i < gameState.livesRemaining
                                ? AppTheme.secondaryColor
                                : Colors.white24,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(flex: 2),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Continuar'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
