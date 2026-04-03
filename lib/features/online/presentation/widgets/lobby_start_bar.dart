import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../application/room_lobby_notifier.dart';

class LobbyStartBar extends StatelessWidget {
  final RoomLobbyState lobbyState;
  final VoidCallback onToggleReady;

  const LobbyStartBar({
    super.key,
    required this.lobbyState,
    required this.onToggleReady,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = lobbyState.isHost;
    final isReady = lobbyState.isReady;
    final canStartVisual = lobbyState.canStartVisual;
    final missingReady = lobbyState.missingReady;

    final buttonText = isHost
        ? canStartVisual
            ? 'Inicio online proximamente'
            : 'Faltan $missingReady listos'
        : isReady
            ? 'Quitar listo'
            : 'Estoy listo';

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
            isHost
                ? 'El inicio real del match llega en el siguiente bloque del online.'
                : isReady
                    ? 'Ya notificaste que estas listo. Espera a que el host lance la partida.'
                    : 'Confirma abajo que estas listo para que el host pueda avanzar.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isHost || lobbyState.isBusyReady
                  ? null
                  : onToggleReady,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHost
                    ? AppTheme.surfaceColor
                    : isReady
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                foregroundColor: isHost
                    ? AppTheme.textSecondary.withValues(alpha: 0.45)
                    : Colors.white,
                disabledBackgroundColor: AppTheme.surfaceColor,
                disabledForegroundColor:
                    AppTheme.textSecondary.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: !isHost && !isReady ? 6 : 0,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isHost
                        ? (canStartVisual
                            ? Icons.play_arrow_rounded
                            : Icons.lock_rounded)
                        : isReady
                            ? Icons.check_circle_rounded
                            : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    buttonText,
                    style: GoogleFonts.nunito(
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
