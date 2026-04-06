import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../providers/game_provider.dart';
import '../../../theme/app_theme.dart';

Future<bool> showActiveGameCancelDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Cancelar partida',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          content: Text(
            '¿Seguro que quieres cancelar la partida? '
            'Se perderá el progreso actual.',
            style: GoogleFonts.nunito(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Seguir jugando',
                style: GoogleFonts.nunito(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
              ),
              child: Text(
                'Cancelar partida',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
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
