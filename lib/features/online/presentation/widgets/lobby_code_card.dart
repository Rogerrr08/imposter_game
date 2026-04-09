import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../../application/room_lobby_notifier.dart';

class LobbyCodeCard extends StatelessWidget {
  final RoomLobbyState lobbyState;

  const LobbyCodeCard({super.key, required this.lobbyState});

  @override
  Widget build(BuildContext context) {
    final room = lobbyState.room!;
    final isHost = lobbyState.isHost;
    final readyCount = lobbyState.readyCount;
    final progress = room.minPlayers == 0
        ? 0.0
        : (readyCount / room.minPlayers).clamp(0, 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 2.5),
            ),
            child: Icon(
              isHost ? Icons.wifi_tethering_rounded : Icons.groups_rounded,
              size: 46,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sala privada',
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.code,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHost
                ? 'Comparte este codigo para que los demas entren a tu sala.'
                : 'Ya estas dentro del lobby. Espera a que el host termine de prepararlo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 14,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(room.gameMode.displayName, AppTheme.primaryColor),
              _badge(
                '${lobbyState.players.length}/${room.maxPlayers} jugadores',
                AppTheme.secondaryColor,
              ),
              _badge('$readyCount listos', AppTheme.successColor),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            readyCount >= room.minPlayers
                ? 'Ya hay suficientes jugadores listos para arrancar.'
                : 'Se necesitan ${room.minPlayers} jugadores listos para empezar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _copyCode(context, room.code),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar codigo'),
          ),
        ],
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Codigo copiado: $code', style: TextStyle(fontFamily: 'Nunito',))),
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
        style: TextStyle(fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
