import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../application/online_match_provider.dart';
import '../application/room_lobby_notifier.dart';
import '../domain/online_room.dart';
import 'widgets/lobby_code_card.dart';
import 'widgets/lobby_config_card.dart';
import 'widgets/lobby_players_section.dart';
import 'widgets/lobby_start_bar.dart';

class RoomLobbyScreen extends ConsumerWidget {
  final String roomId;

  const RoomLobbyScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(roomLobbyNotifierProvider(roomId));

    // Show snackbar when an error surfaces
    ref.listen<AsyncValue<RoomLobbyState>>(
      roomLobbyNotifierProvider(roomId),
      (prev, next) {
        final error = next.value?.error;
        if (error != null && error != prev?.value?.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error, style: TextStyle(fontFamily: 'Nunito',))),
          );
        }

        // Non-host: navigate to match when room transitions to playing
        final prevRoom = prev?.value?.room;
        final nextRoom = next.value?.room;
        if (prevRoom?.status == OnlineRoomStatus.waiting &&
            nextRoom?.status == OnlineRoomStatus.playing) {
          _navigateToActiveMatch(context, ref);
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleLeave(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => _handleLeave(context, ref),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Lobby privado',
            style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: () => _handleLeave(context, ref),
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Salir de la sala',
            ),
          ],
        ),
        body: asyncState.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (_, __) => _buildCenteredMessage(
            title: 'No pudimos cargar la sala',
            subtitle:
                'Puede que la sala ya no este disponible. Intenta salir y volver.',
          ),
          data: (lobbyState) {
            final profile = lobbyState.profile;
            if (profile == null || !profile.hasDisplayName) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/online/display-name');
              });
              return const SizedBox.shrink();
            }

            if (lobbyState.room == null) {
              return _buildCenteredMessage(
                title: 'La sala ya no existe',
                subtitle: 'Parece que fue cerrada o eliminada.',
              );
            }

            if (lobbyState.currentPlayer == null) {
              return _buildCenteredMessage(
                title: 'No encontramos tu jugador en la sala',
                subtitle:
                    'Puede que todavia se este sincronizando o que ya no formes parte del lobby.',
              );
            }

            return _buildLobbyContent(context, ref, lobbyState);
          },
        ),
      ),
    );
  }

  Widget _buildLobbyContent(
    BuildContext context,
    WidgetRef ref,
    RoomLobbyState lobbyState,
  ) {
    final notifier = ref.read(roomLobbyNotifierProvider(roomId).notifier);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LobbyCodeCard(lobbyState: lobbyState),
                  const SizedBox(height: 24),
                  _buildReadyCard(lobbyState),
                  const SizedBox(height: 24),
                  LobbyConfigCard(
                    lobbyState: lobbyState,
                    onConfigChanged: ({
                      categories,
                      hintsEnabled,
                      impostorCount,
                      durationSeconds,
                    }) {
                      notifier.updateConfig(
                        categories: categories,
                        hintsEnabled: hintsEnabled,
                        impostorCount: impostorCount,
                        durationSeconds: durationSeconds,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LobbyPlayersSection(
                    players: lobbyState.players,
                    currentUserId: lobbyState.profile!.id,
                    isHost: lobbyState.isHost,
                    onKickPlayer: (userId) => notifier.kickPlayer(userId),
                  ),
                ],
              ),
            ),
          ),
          LobbyStartBar(
            lobbyState: lobbyState,
            onToggleReady: () => notifier.toggleReady(),
            onStartMatch: () => _handleStartMatch(context, ref),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ready card (kept inline — depends on computed fields from state)
  // ---------------------------------------------------------------------------

  Widget _buildReadyCard(RoomLobbyState s) {
    final isHost = s.isHost;
    final isReady = s.isReady;
    final missingPlayers = s.missingPlayers;
    final missingReady = s.missingReady;

    final title = isHost
        ? 'Tu sala ya esta lista para configurarse'
        : isReady
            ? 'Ya estas listo'
            : 'Marca cuando estes listo';

    final subtitle = isHost
        ? missingPlayers > 0
            ? 'Faltan $missingPlayers jugador${missingPlayers == 1 ? '' : 'es'} para completar el minimo.'
            : missingReady > 0
                ? 'Aun faltan $missingReady jugador${missingReady == 1 ? '' : 'es'} listos para empezar.'
                : 'La sala ya cumplio el minimo de listos y queda preparada para el siguiente paso del online.'
        : isReady
            ? 'Puedes esperar mientras el host termina de ajustar la sala.'
            : 'Cuando lo confirmes con el boton inferior, el host lo vera al instante.';

    final accentColor = isHost
        ? AppTheme.primaryColor
        : isReady
            ? AppTheme.successColor
            : AppTheme.warningColor;

    final backgroundColor = isHost
        ? AppTheme.primaryColor.withValues(alpha: 0.09)
        : isReady
            ? AppTheme.successColor.withValues(alpha: 0.10)
            : AppTheme.warningColor.withValues(alpha: 0.10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHost
                  ? Icons.admin_panel_settings_rounded
                  : isReady
                      ? Icons.check_circle_rounded
                      : Icons.notifications_active_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'Nunito',
                    fontSize: 13,
                    height: 1.4,
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _navigateToActiveMatch(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final matchId = await ref
        .read(onlineMatchRepositoryProvider)
        .getActiveMatchForRoom(roomId);
    if (matchId != null && context.mounted) {
      context.go('/online/match/$matchId');
    }
  }

  Future<void> _handleStartMatch(BuildContext context, WidgetRef ref) async {
    final matchId = await ref
        .read(roomLobbyNotifierProvider(roomId).notifier)
        .startMatch();
    if (matchId != null && context.mounted) {
      context.go('/online/match/$matchId');
    }
  }

  Future<void> _handleLeave(BuildContext context, WidgetRef ref) async {
    final s = ref.read(roomLobbyNotifierProvider(roomId)).value;
    if (s == null || s.isLeaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Salir de la sala',
          style: TextStyle(fontFamily: 'Nunito',fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Saldras del lobby actual. Si eras el host, la sala pasara al siguiente jugador.',
          style: TextStyle(fontFamily: 'Nunito',color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final left = await ref
        .read(roomLobbyNotifierProvider(roomId).notifier)
        .leaveRoom();
    if (left && context.mounted) {
      context.go('/online');
    }
  }

  Widget _buildCenteredMessage({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 56,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
