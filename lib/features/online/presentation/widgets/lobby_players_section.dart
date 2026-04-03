import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../screens/game_setup/widgets/section_header.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/online_room.dart';

class LobbyPlayersSection extends StatelessWidget {
  final List<OnlineRoomPlayer> players;
  final String currentUserId;

  const LobbyPlayersSection({
    super.key,
    required this.players,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.people_alt_rounded,
          title: 'Jugadores: ${players.length}',
        ),
        const SizedBox(height: 8),
        Text(
          'El orden de esta lista sera la base para revelar turnos y acciones online.',
          style: GoogleFonts.nunito(
            fontSize: 12,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...players.map(
          (player) => _PlayerTile(
            player: player,
            isCurrentUser: player.userId == currentUserId,
          ),
        ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final OnlineRoomPlayer player;
  final bool isCurrentUser;

  const _PlayerTile({required this.player, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final avatarColor = player.isHost
        ? AppTheme.primaryColor
        : player.isReady
            ? AppTheme.successColor
            : AppTheme.textSecondary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.displayName.characters.first.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.displayName,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      _badge('Tu', AppTheme.primaryColor),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Jugador ${player.seatOrder}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: player.isConnected
                            ? AppTheme.successColor
                            : AppTheme.textSecondary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      player.isConnected ? 'Conectado' : 'Desconectado',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: player.isConnected
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (player.isHost) _badge('Host', AppTheme.primaryColor),
              if (player.isHost) const SizedBox(height: 8),
              _badge(
                player.isReady ? 'Listo' : 'Esperando',
                player.isReady ? AppTheme.successColor : AppTheme.warningColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
