import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/game_provider.dart';
import '../../../theme/app_theme.dart';

Future<bool> showActiveGameCancelDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(
            'Cancelar partida',
            style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
          ),
          content: Text(
            '¿Seguro que quieres cancelar la partida? '
            'Se perderá el progreso actual.',
            style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Seguir jugando',
                style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
              ),
              child: const Text(
                'Cancelar partida',
                style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirmed || !context.mounted) {
    return false;
  }

  final game = ref.read(gameProvider);
  final groupId = game?.config.groupId;
  ref.read(gameProvider.notifier).clearGame();
  context.go('/setup', extra: groupId);
  return true;
}
