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
  // 0 = who is voting, 1 = who to eliminate, 2 = confirm
  int _step = 0;
  String? _votedBy;
  String? _selectedPlayer;

  void _onNameSelected(String name) {
    if (_step == 0) {
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
          'Voto no v\u00E1lido',
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

  Widget _buildStepView(ActiveGame gameState) {
    final playerNames = gameState.activePlayers.map((p) => p.name).toList();
    final isFirstStep = _step == 0;
    final stepTitle =
        isFirstStep ? '\u00BFQui\u00E9n est\u00E1 votando?' : '\u00BFA qui\u00E9n eliminamos?';
    final stepHint =
        isFirstStep ? 'Escribe tu nombre...' : 'Nombre del sospechoso...';
    final stepSubtitle = isFirstStep
        ? 'Solo los civiles pueden votar.'
        : 'Votando: $_votedBy';

    // Filter out voter from options in step 2
    final availableNames =
        isFirstStep ? playerNames : playerNames.where((n) => n != _votedBy).toList();

    return Column(
      children: [
        const SizedBox(height: 16),
        // Top bar with back/cancel and lives
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
            // Lives indicator
            Row(
              mainAxisSize: MainAxisSize.min,
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
                          : AppTheme.textSecondary.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        const Spacer(flex: 1),
        // Step indicator
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
        // Title
        Text(
          stepTitle,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          stepSubtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Autocomplete field
        _buildAutocompleteField(
          playerNames: availableNames,
          hint: stepHint,
          onSelected: _onNameSelected,
        ),
        const Spacer(flex: 3),
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

  Widget _buildAutocompleteField({
    required List<String> playerNames,
    required String hint,
    required ValueChanged<String> onSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          key: ValueKey('autocomplete_step_$_step'),
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return playerNames;
            return playerNames.where(
              (name) => name.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
            );
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            // Auto-focus on build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!focusNode.hasFocus) {
                focusNode.requestFocus();
              }
            });

            return TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (text) {
                final trimmed = text.trim();
                final match = playerNames
                    .where((name) =>
                        name.toLowerCase() == trimmed.toLowerCase())
                    .firstOrNull;
                if (match != null) {
                  onSelected(match);
                }
              },
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 18,
              ),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                elevation: 4,
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppTheme.textSecondary.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
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
        // Confirmation card
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
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Voter
              _buildConfirmRow(
                label: 'Vota:',
                name: _votedBy!,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              // Arrow
              Icon(
                Icons.arrow_downward_rounded,
                color: AppTheme.secondaryColor,
                size: 28,
              ),
              const SizedBox(height: 16),
              // Target
              _buildConfirmRow(
                label: 'Eliminar a:',
                name: _selectedPlayer!,
                color: AppTheme.secondaryColor,
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),
        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmVote,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
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
          onPressed: _stepBack,
          child: Text(
            'Cambiar',
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
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
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
