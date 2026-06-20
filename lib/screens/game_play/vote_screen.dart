import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/action_reveal.dart';
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key});

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  int _step = 0;
  String? _votedBy;
  String? _selectedPlayer;
  String? _classicSelectedTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = ref.read(gameProvider);
      if (game?.config.mode == GameMode.classic &&
          game?.phase != GamePhase.voting) {
        ref.read(gameProvider.notifier).startVotingRound();
      }
    });
  }

  void _onNameSelected(String name) {
    HapticFeedback.selectionClick();
    if (_step == 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _votedBy = name;
        _step = 1;
      });
    } else if (_step == 1) {
      setState(() {
        _selectedPlayer = name;
        _step = 2;
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _stepBack() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _votedBy = null;
      });
    } else if (_step == 2) {
      setState(() {
        _step = 1;
        _selectedPlayer = null;
      });
    }
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
      _showVoteError('Los impostores no pueden proponer votos.');
      return;
    }

    if (_selectedPlayer == _votedBy) {
      _showVoteError('Un jugador no puede votarse a s\u00ED mismo.');
      return;
    }

    final wasImpostor = ref
        .read(gameProvider.notifier)
        .eliminatePlayer(_selectedPlayer!, votedBy: _votedBy);
    final updatedGameState = ref.read(gameProvider);

    context.go(
      '/action-reveal',
      extra: ActionRevealData(
        type: ActionRevealType.vote,
        success: wasImpostor,
        subjectText: _selectedPlayer!,
        actorText: _votedBy,
        livesRemaining: wasImpostor ? null : updatedGameState?.livesRemaining,
      ),
    );
  }

  void _submitClassicVote(String voterName) {
    if (_classicSelectedTarget == null) return;

    final submitted = ref
        .read(gameProvider.notifier)
        .submitClassicVote(
          voterName: voterName,
          targetName: _classicSelectedTarget!,
        );
    if (!submitted) {
      _showVoteError('No se pudo registrar ese voto.');
      return;
    }

    final updatedGame = ref.read(gameProvider);
    if (updatedGame == null) return;

    if (updatedGame.lastEliminatedPlayerName != null) {
      _goToClassicReveal(updatedGame);
      return;
    }

    setState(() {
      _classicSelectedTarget = null;
    });
  }

  void _submitClassicTieBreak() {
    final target = _classicSelectedTarget;
    if (target == null) return;

    final resolved = ref.read(gameProvider.notifier).resolveClassicTie(target);
    if (!resolved) {
      _showVoteError('No se pudo resolver el desempate.');
      return;
    }

    final updatedGame = ref.read(gameProvider);
    if (updatedGame == null) return;
    _goToClassicReveal(updatedGame);
  }

  void _goToClassicReveal(ActiveGame updatedGame) {
    final eliminatedName = updatedGame.lastEliminatedPlayerName;
    final wasImpostor = updatedGame.lastEliminatedWasImpostor;
    if (eliminatedName == null || wasImpostor == null) return;

    context.go(
      '/action-reveal',
      extra: ActionRevealData(
        type: ActionRevealType.vote,
        success: wasImpostor,
        subjectText: eliminatedName,
        voteTallies: updatedGame.lastVoteTallies,
      ),
    );
  }

  void _showVoteError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Voto no v\u00E1lido',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.config.mode == GameMode.classic) {
      return _buildClassicVoteScreen(gameState);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == 2
              ? _buildConfirmView(gameState)
              : _buildStepView(gameState),
        ),
      ),
    );
  }

  Widget _buildClassicVoteScreen(ActiveGame gameState) {
    final tieCandidates = gameState.classicTieCandidates;
    final currentVoter = gameState.currentClassicVoterName;
    final totalVoters = gameState.classicVotingOrder.length;
    final progress = totalVoters == 0
        ? 0
        : ((gameState.classicVotes.length + 1).clamp(1, totalVoters));

    final optionNames = tieCandidates.isNotEmpty
        ? tieCandidates
        : gameState.activePlayers
              .where((player) => player.name != currentVoter)
              .map((player) => player.name)
              .toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tieCandidates.isNotEmpty
                    ? 'Empate en la votaci\u00F3n'
                    : 'Votaci\u00F3n an\u00F3nima',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tieCandidates.isNotEmpty
                    ? 'Entre todos decidan cual de los empatados sera eliminado.'
                    : 'Participante $progress de $totalVoters',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              if (tieCandidates.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ahora vota',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentVoter ?? '-',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tieCandidates.isNotEmpty
                      ? 'Seleccionen al eliminado:'
                      : 'Selecciona a quien eliminar:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: optionNames.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final name = optionNames[index];
                    final selected = _classicSelectedTarget == name;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _classicSelectedTarget = name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor.withValues(alpha: 0.16)
                              : AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary.withValues(
                                    alpha: 0.15,
                                  ),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.primaryColor,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _classicSelectedTarget == null
                      ? null
                      : () {
                          if (tieCandidates.isNotEmpty) {
                            _submitClassicTieBreak();
                          } else if (currentVoter != null) {
                            _submitClassicVote(currentVoter);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    disabledBackgroundColor: AppTheme.secondaryColor.withValues(
                      alpha: 0.3,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    tieCandidates.isNotEmpty
                        ? 'Elegir eliminado'
                        : 'Confirmar voto',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepView(ActiveGame gameState) {
    final playerNames = gameState.activePlayers.map((p) => p.name).toList();
    final isFirstStep = _step == 0;
    final stepTitle = isFirstStep
        ? 'Quien esta votando?'
        : 'A quien eliminamos?';
    final stepSubtitle = isFirstStep
        ? 'Solo los civiles pueden votar.'
        : 'Votando: $_votedBy';

    final availableNames = isFirstStep
        ? playerNames
        : playerNames.where((name) => name != _votedBy).toList();

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
            // Las vidas no se muestran durante la votación: el contador
            // filtraba el rol del eliminado (si bajaba, era civil). La
            // mecánica sigue intacta (se cuentan internamente).
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepDot(0),
            Container(
              width: 32,
              height: 2,
              color: _step >= 1
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary.withValues(alpha: 0.2),
            ),
            _buildStepDot(1),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          stepTitle,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          stepSubtitle,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _buildPlayerChips(availableNames),
      ],
    );
  }

  Widget _buildStepDot(int step) {
    final isActive = _step >= step;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? AppTheme.primaryColor
            : AppTheme.textSecondary.withValues(alpha: 0.2),
      ),
    );
  }

  // Selección por chips tocables (antes era un campo de texto que obligaba a
  // escribir el nombre). Más rápido y "de fiesta". La lógica de voto no cambia:
  // al tocar un chip se llama a _onNameSelected con ese nombre.
  Widget _buildPlayerChips(List<String> names) {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppTheme.sp12,
            runSpacing: AppTheme.sp12,
            children: [
              for (final name in names)
                _PlayerChip(name: name, onTap: () => _onNameSelected(name)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmView(ActiveGame gameState) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: _stepBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
          ],
        ),
        const Spacer(flex: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Confirmar voto',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildConfirmRow(
                label: 'Vota:',
                name: _votedBy!,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Icon(
                Icons.arrow_downward_rounded,
                color: AppTheme.secondaryColor,
                size: 28,
              ),
              const SizedBox(height: 16),
              _buildConfirmRow(
                label: 'Eliminar a:',
                name: _selectedPlayer!,
                color: AppTheme.secondaryColor,
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmVote,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Confirmar Voto'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _stepBack,
          child: Text(
            'Cambiar',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildConfirmRow({
    required String label,
    required String name,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Chip tocable con la inicial del jugador. Reemplaza el campo de texto de la
/// votación Express: tocar = seleccionar (la lógica de voto no cambia).
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final accent = AppTheme.primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.rFull),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.rFull),
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: AppTheme.glowSoft(accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                name,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
