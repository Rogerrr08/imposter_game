import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../application/room_lobby_notifier.dart';

class LobbyStartBar extends StatelessWidget {
  final RoomLobbyState lobbyState;
  final VoidCallback onToggleReady;
  final VoidCallback onStartMatch;

  const LobbyStartBar({
    super.key,
    required this.lobbyState,
    required this.onToggleReady,
    required this.onStartMatch,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = lobbyState.isHost;
    final isReady = lobbyState.isReady;
    final canStart = lobbyState.canStartVisual;
    final isStarting = lobbyState.isStarting;
    final missingReady = lobbyState.missingReady;

    final String buttonText;
    final VoidCallback? onPressed;
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final double elevation;

    if (isHost) {
      if (isStarting) {
        buttonText = 'Iniciando partida...';
        onPressed = null;
        bgColor = AppTheme.primaryColor;
        fgColor = Colors.white;
        icon = Icons.hourglass_top_rounded;
        elevation = 0;
      } else if (canStart) {
        buttonText = 'Iniciar partida';
        onPressed = onStartMatch;
        bgColor = AppTheme.primaryColor;
        fgColor = Colors.white;
        icon = Icons.play_arrow_rounded;
        elevation = 6;
      } else {
        final missingPlayers = lobbyState.missingPlayers;
        if (missingPlayers > 0) {
          buttonText = 'Faltan $missingPlayers jugador${missingPlayers > 1 ? 'es' : ''}';
          icon = Icons.group_add_rounded;
        } else {
          buttonText = 'Faltan $missingReady listos';
          icon = Icons.lock_rounded;
        }
        onPressed = null;
        bgColor = AppTheme.surfaceColor;
        fgColor = AppTheme.textSecondary.withValues(alpha: 0.45);
        elevation = 0;
      }
    } else {
      if (isReady) {
        buttonText = 'Quitar listo';
        onPressed = lobbyState.isBusyReady ? null : onToggleReady;
        bgColor = AppTheme.successColor;
        fgColor = Colors.white;
        icon = Icons.check_circle_rounded;
        elevation = 0;
      } else {
        buttonText = 'Estoy listo';
        onPressed = lobbyState.isBusyReady ? null : onToggleReady;
        bgColor = AppTheme.primaryColor;
        fgColor = Colors.white;
        icon = Icons.play_arrow_rounded;
        elevation = 6;
      }
    }

    final String subtitle;
    if (isHost) {
      subtitle = canStart
          ? 'Todos los jugadores están listos. Puedes iniciar la partida.'
          : 'Necesitas que todos los jugadores estén listos para iniciar.';
    } else {
      subtitle = isReady
          ? 'Ya notificaste que estás listo. Espera a que el host lance la partida.'
          : 'Confirma abajo que estás listo para que el host pueda avanzar.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(fontFamily: 'Nunito',
              fontSize: 12,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: fgColor,
                disabledBackgroundColor: isStarting
                    ? AppTheme.primaryColor.withValues(alpha: 0.7)
                    : AppTheme.surfaceColor,
                disabledForegroundColor: isStarting
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.textSecondary.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: elevation,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isStarting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    buttonText,
                    style: TextStyle(fontFamily: 'Nunito',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
