import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../theme/app_theme.dart';

class GameResultsScreen extends ConsumerWidget {
  const GameResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      return const Scaffold(
        body: Center(child: Text('No hay partida activa')),
      );
    }

    final civilsWon = game.civilsWon;
    final impostorGuessed = game.impostorGuessedWord;
    final groupId = game.config.groupId;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildResultHeader(civilsWon, impostorGuessed),
              const SizedBox(height: 24),
              _buildSpotlightSection(game),
              if (civilsWon && !impostorGuessed) ...[
                const SizedBox(height: 18),
                _buildImpostorOverrideButton(context, ref, game),
              ],
              const SizedBox(height: 32),
              _buildPlayerResults(game),
              const SizedBox(height: 32),
              _buildPointsSummary(game),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(gameProvider.notifier).clearGame();
                    context.go('/setup', extra: groupId);
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Jugar de Nuevo'),
                ),
              ),
              if (groupId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(gameProvider.notifier).clearGame();
                      context.go('/groups/$groupId');
                    },
                    icon: const Icon(Icons.group_rounded),
                    label: const Text('Volver al Grupo'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(gameProvider.notifier).clearGame();
                    context.go('/');
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Inicio'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightSection(ActiveGame game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWordReveal(game.secretWord, game.wordCategory.displayName),
          const SizedBox(height: 16),
          _buildImpostorHints(game),
        ],
      ),
    );
  }

  Widget _buildResultHeader(bool civilsWon, bool impostorGuessed) {
    final color = civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;
    final title = civilsWon ? '¡Civiles Ganan!' : '¡Impostores Ganan!';
    final subtitle = civilsWon
        ? 'Todos los impostores fueron descubiertos'
        : impostorGuessed
            ? 'El impostor adivinó la palabra secreta'
            : 'Los civiles se quedaron sin vidas o ya solo quedaban dos jugadores';

    return Column(
      children: [
        Image.asset(
          civilsWon
              ? 'assets/images/player_civil.png'
              : 'assets/images/player_impostor.png',
          width: 188,
          height: 188,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordReveal(String word, String category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.38),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'La Palabra Secreta',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            word,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: AppTheme.warningColor,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              category,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpostorHints(ActiveGame game) {
    final impostorsWithHints =
        game.impostors.where((player) => player.hint != null).toList();

    if (impostorsWithHints.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 18,
                color: AppTheme.secondaryColor.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 8),
              Text(
                'Pistas de los impostores',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...impostorsWithHints.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.name,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        player.hint!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerResults(ActiveGame game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jugadores',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...game.players.map(_buildPlayerCard),
      ],
    );
  }

  Widget _buildPlayerCard(GamePlayer player) {
    final isImpostor = player.role == PlayerRole.impostor;
    final roleColor =
        isImpostor ? AppTheme.secondaryColor : AppTheme.successColor;
    final roleText = isImpostor ? 'IMPOSTOR' : 'CIVIL';
    final roleIcon = isImpostor ? Icons.psychology_alt : Icons.shield;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isImpostor
              ? AppTheme.secondaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(roleIcon, color: roleColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    decoration:
                        player.isEliminated ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  roleText,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (player.isEliminated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Eliminado',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (player.points >= 0
                      ? AppTheme.successColor
                      : AppTheme.errorColor)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${player.points >= 0 ? '+' : ''}${player.points}',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: player.points >= 0
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsSummary(ActiveGame game) {
    final totalPoints = game.players.fold<int>(0, (sum, player) {
      return sum + player.points;
    });
    final impostorPoints = game.impostors.fold<int>(0, (sum, player) {
      return sum + player.points;
    });
    final civilPoints = totalPoints - impostorPoints;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _pointColumn('Civiles', civilPoints, AppTheme.successColor),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
          ),
          _pointColumn('Impostores', impostorPoints, AppTheme.secondaryColor),
        ],
      ),
    );
  }

  Widget _buildImpostorOverrideButton(
    BuildContext context,
    WidgetRef ref,
    ActiveGame game,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showImpostorOverrideDialog(context, ref, game),
        icon: const Icon(Icons.psychology_alt, size: 20),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.secondaryColor,
          side: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        label: Text(
          'Darle victoria al impostor',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showImpostorOverrideDialog(
    BuildContext context,
    WidgetRef ref,
    ActiveGame game,
  ) {
    final impostors = game.impostors;

    if (impostors.length == 1) {
      _confirmOverride(context, ref, impostors.first.name);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '¿Qué impostor adivinó?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: impostors.map((impostor) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _confirmOverride(context, ref, impostor.name);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    impostor.name,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOverride(
    BuildContext context,
    WidgetRef ref,
    String impostorName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Confirmar cambio',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se cambiará el resultado a victoria de impostores. '
          '$impostorName recibirá 3 pts y los demás impostores 1 pt. '
          'Los civiles no recibirán puntos.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(gameProvider.notifier)
                  .overrideImpostorGuessedCorrectly(impostorName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: Text(
              'Confirmar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointColumn(String label, int points, Color color) {
    return Column(
      children: [
        Text(
          '$points pts',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
