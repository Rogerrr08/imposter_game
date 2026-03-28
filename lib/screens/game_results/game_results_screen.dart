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
              const SizedBox(height: 20),
              // Result header
              _buildResultHeader(civilsWon, impostorGuessed),
              const SizedBox(height: 32),
              // Secret word reveal
              _buildWordReveal(game.secretWord, game.wordCategory.displayName),
              const SizedBox(height: 16),
              // Impostor hints
              _buildImpostorHints(game),
              const SizedBox(height: 32),
              // Player results
              _buildPlayerResults(game),
              const SizedBox(height: 32),
              // Points summary
              _buildPointsSummary(game),
              const SizedBox(height: 40),
              // Action buttons
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

  Widget _buildResultHeader(bool civilsWon, bool impostorGuessed) {
    final icon = civilsWon ? Icons.shield : Icons.psychology_alt;
    final color = civilsWon ? AppTheme.successColor : AppTheme.secondaryColor;
    final title = civilsWon ? '¡Civiles Ganan!' : '¡Impostores Ganan!';
    final subtitle = civilsWon
        ? 'Todos los impostores fueron descubiertos'
        : impostorGuessed
            ? 'El impostor adivinó la palabra secreta'
            : 'Los civiles se quedaron sin vidas o ya solo quedaban dos jugadores';

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(icon, size: 50, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white60,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWordReveal(String word, String category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'La Palabra Secreta',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            word,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpostorHints(ActiveGame game) {
    final impostorsWithHints =
        game.impostors.where((p) => p.hint != null).toList();

    if (impostorsWithHints.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 16,
                color: AppTheme.secondaryColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Pistas de los impostores',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.secondaryColor.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...impostorsWithHints.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${p.name}: ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      p.hint!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ),
              )),
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
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...game.players.map((player) => _buildPlayerCard(player)),
      ],
    );
  }

  Widget _buildPlayerCard(GamePlayer player) {
    final isImpostor = player.role == PlayerRole.impostor;
    final roleColor = isImpostor ? AppTheme.secondaryColor : AppTheme.successColor;
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
          width: 1,
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
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: player.isEliminated
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  roleText,
                  style: GoogleFonts.poppins(
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
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Eliminado',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${player.points}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsSummary(ActiveGame game) {
    final totalPoints = game.players.fold<int>(0, (sum, p) => sum + p.points);
    final impostorPoints = game.impostors.fold<int>(0, (sum, p) => sum + p.points);
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
            color: Colors.white12,
          ),
          _pointColumn('Impostores', impostorPoints, AppTheme.secondaryColor),
        ],
      ),
    );
  }

  Widget _pointColumn(String label, int points, Color color) {
    return Column(
      children: [
        Text(
          '$points pts',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}
