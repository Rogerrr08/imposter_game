import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String? _selectedPlayer;
  String? _votedBy;

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
      _showVoteError('Un jugador no puede votarse a sí mismo.');
      return;
    }

    final wasImpostor = ref.read(gameProvider.notifier).eliminatePlayer(
          _selectedPlayer!,
          votedBy: _votedBy,
        );
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

  void _showVoteError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Voto no válido',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Entendido',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildVotingView(gameState),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required List<String> playerNames,
    required String label,
    required ValueChanged<String?> onSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return playerNames;
            return playerNames.where(
              (name) => name.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
            );
          },
          onSelected: (value) => onSelected(value),
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            controller.addListener(() {
              final text = controller.text.trim();
              final match = playerNames
                  .where((name) => name.toLowerCase() == text.toLowerCase())
                  .firstOrNull;
              onSelected(match);
            });

            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.poppins(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVotingView(ActiveGame gameState) {
    final playerNames = gameState.activePlayers.map((p) => p.name).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/player_civil.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votación',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < ActiveGame.maxLives; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                i < gameState.livesRemaining
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: i < gameState.livesRemaining
                                    ? AppTheme.secondaryColor
                                    : AppTheme.textSecondary
                                        .withValues(alpha: 0.3),
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${gameState.livesRemaining} vida${gameState.livesRemaining == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: gameState.livesRemaining == 1
                              ? AppTheme.secondaryColor
                              : AppTheme.textSecondary,
                          fontWeight: gameState.livesRemaining == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Instructions box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Solo los civiles pueden votar.\nElige a quien crees que es el impostor.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textPrimary.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Field 1: who is voting
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '\u00BFQui\u00E9n est\u00E1 votando?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAutocompleteField(
                    playerNames: playerNames,
                    label: 'Escribe tu nombre...',
                    onSelected: (value) => setState(() => _votedBy = value),
                  ),
                  const SizedBox(height: 20),
                  // Field 2: who to eliminate
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '\u00BFA qui\u00E9n quieres eliminar?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAutocompleteField(
                    playerNames: playerNames,
                    label: 'Nombre del sospechoso...',
                    onSelected: (value) =>
                        setState(() => _selectedPlayer = value),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedPlayer != null && _votedBy != null
                          ? _confirmVote
                          : null,
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
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
