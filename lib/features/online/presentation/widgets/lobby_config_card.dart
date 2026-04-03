import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../data/word_bank.dart';
import '../../../../screens/game_setup/widgets/category_section.dart';
import '../../domain/online_room.dart';
import '../../../../screens/game_setup/widgets/hints_toggle.dart';
import '../../../../screens/game_setup/widgets/impostor_count_section.dart';
import '../../../../screens/game_setup/widgets/section_header.dart';
import '../../../../screens/game_setup/widgets/timer_section.dart';
import '../../../../theme/app_theme.dart';
import '../../application/room_lobby_notifier.dart';

class LobbyConfigCard extends StatelessWidget {
  final RoomLobbyState lobbyState;
  final void Function({
    List<WordCategory>? categories,
    bool? hintsEnabled,
    int? impostorCount,
    int? durationSeconds,
  }) onConfigChanged;

  const LobbyConfigCard({
    super.key,
    required this.lobbyState,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    final room = lobbyState.room!;
    final isHost = lobbyState.isHost;
    final selectedCategories = lobbyState.draftCategories;
    final selectedHintsEnabled = lobbyState.draftHintsEnabled;
    final selectedImpostorCount = lobbyState.draftImpostorCount;
    final selectedDurationSeconds = lobbyState.draftDurationSeconds;
    final maxImpostors = lobbyState.maxImpostors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.tune_rounded,
            title: 'Configuracion de la sala',
          ),
          const SizedBox(height: 8),
          Text(
            isHost
                ? 'Usa exactamente el mismo lenguaje visual del setup local, pero sincronizado con toda la sala.'
                : 'Estas viendo la misma configuracion que el host mantiene para toda la sala.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildGameModeRow(room),
          if (!isHost) ...[
            const SizedBox(height: 14),
            _buildLockedNotice(),
          ],
          const SizedBox(height: 22),
          AbsorbPointer(
            absorbing: !isHost,
            child: Opacity(
              opacity: isHost ? 1 : 0.96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategorySection(
                    selectedCategories: selectedCategories.toSet(),
                    onToggle: (category) {
                      final next = selectedCategories.toList();
                      if (next.contains(category)) {
                        if (next.length > 1) next.remove(category);
                      } else {
                        next.add(category);
                      }
                      onConfigChanged(categories: next);
                    },
                    onSelectAll: () => onConfigChanged(
                      categories: List<WordCategory>.from(WordCategory.values),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ImpostorCountSection(
                    impostorCount: selectedImpostorCount,
                    maxImpostors: maxImpostors,
                    playerCount: lobbyState.players.length,
                    minPlayers: room.minPlayers,
                    onDecrement: !isHost || selectedImpostorCount <= 1
                        ? null
                        : () => onConfigChanged(
                              impostorCount: selectedImpostorCount - 1,
                            ),
                    onIncrement: !isHost || selectedImpostorCount >= maxImpostors
                        ? null
                        : () => onConfigChanged(
                              impostorCount: selectedImpostorCount + 1,
                            ),
                  ),
                  const SizedBox(height: 24),
                  HintsToggle(
                    hintsEnabled: selectedHintsEnabled,
                    onChanged: (value) => onConfigChanged(hintsEnabled: value),
                  ),
                  const SizedBox(height: 24),
                  TimerSection(
                    durationSeconds: selectedDurationSeconds,
                    onDurationChanged: (value) =>
                        onConfigChanged(durationSeconds: value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameModeRow(OnlineRoom room) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radio_button_checked_rounded,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.gameMode.displayName,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  room.gameMode.subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    height: 1.3,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Solo el host puede editar esta configuracion, pero aqui siempre veras los cambios al momento.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
