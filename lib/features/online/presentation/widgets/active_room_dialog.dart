import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../application/online_match_provider.dart';

/// Result returned by the active room dialog.
enum ActiveRoomAction { continueRoom, leaveRoom }

/// Shows a modal when the user already has an active room.
/// Returns [ActiveRoomAction.continueRoom] to navigate to that room/match,
/// or [ActiveRoomAction.leaveRoom] if the user chose to leave.
/// Returns null if dismissed.
Future<ActiveRoomAction?> showActiveRoomDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String roomId,
}) async {
  // Determine if the room has an active match (playing vs waiting)
  final matchId = await ref
      .read(onlineMatchRepositoryProvider)
      .getActiveMatchForRoom(roomId);

  final isPlaying = matchId != null;

  if (!context.mounted) return null;

  return showDialog<ActiveRoomAction>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ActiveRoomDialog(
      isPlaying: isPlaying,
      roomId: roomId,
    ),
  );
}

class _ActiveRoomDialog extends StatefulWidget {
  final bool isPlaying;
  final String roomId;

  const _ActiveRoomDialog({
    required this.isPlaying,
    required this.roomId,
  });

  @override
  State<_ActiveRoomDialog> createState() => _ActiveRoomDialogState();
}

class _ActiveRoomDialogState extends State<_ActiveRoomDialog> {
  bool _confirmingLeave = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.isPlaying
        ? 'Tienes una partida en curso'
        : 'Tienes un lobby abierto';

    final subtitle = widget.isPlaying
        ? 'Puedes volver a la partida o salir definitivamente.'
        : 'Puedes continuar en el lobby o salir y crear una sala nueva.';

    final icon =
        widget.isPlaying ? Icons.sports_esports_rounded : Icons.group_rounded;

    final iconColor =
        widget.isPlaying ? AppTheme.successColor : AppTheme.warningColor;

    final leaveLabel = _confirmingLeave
        ? 'Toca de nuevo para confirmar'
        : widget.isPlaying
            ? 'Salir de la partida'
            : 'Salir de la sala';

    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Continue button (primary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, ActiveRoomAction.continueRoom),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar'),
              ),
            ),
            const SizedBox(height: 10),

            // Leave button (destructive, tap-again-to-confirm)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (_confirmingLeave) {
                    Navigator.pop(context, ActiveRoomAction.leaveRoom);
                  } else {
                    setState(() => _confirmingLeave = true);
                  }
                },
                icon: Icon(
                  _confirmingLeave
                      ? Icons.warning_amber_rounded
                      : Icons.logout_rounded,
                ),
                label: Text(leaveLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _confirmingLeave
                      ? AppTheme.errorColor
                      : AppTheme.secondaryColor,
                  side: BorderSide(
                    color: (_confirmingLeave
                            ? AppTheme.errorColor
                            : AppTheme.secondaryColor)
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
