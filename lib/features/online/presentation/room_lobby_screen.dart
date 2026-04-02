import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/word_bank.dart';
import '../../../theme/app_theme.dart';
import '../application/online_auth_provider.dart';
import '../application/online_lobby_sync_provider.dart';
import '../application/online_rooms_provider.dart';
import '../domain/online_room.dart';

class RoomLobbyScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomLobbyScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  static const List<int> _durationOptions = [60, 120, 180, 300, 600, 900];

  bool _busyReady = false;
  bool _leaving = false;
  bool _configRequestInFlight = false;
  bool _configSyncPending = false;
  bool _configDirty = false;
  bool _hasOptimisticConfig = false;

  OnlineProfile? _lastProfile;
  OnlineRoom? _lastRoom;
  List<OnlineRoomPlayer>? _lastPlayers;
  String? _draftRoomId;
  List<WordCategory>? _draftCategories;
  bool? _draftHintsEnabled;
  int? _draftImpostorCount;
  int? _draftDurationSeconds;
  Timer? _configDebounceTimer;

  @override
  void dispose() {
    _configDebounceTimer?.cancel();
    super.dispose();
  }

  void _refreshLobbyProviders() {
    ref.invalidate(onlineRoomProvider(widget.roomId));
    ref.invalidate(onlineRoomPlayersProvider(widget.roomId));
  }

  void _handleBackAttempt() {
    if (_leaving) return;
    _leaveRoom();
  }

  void _syncDraftConfigFromRoom(OnlineRoom room) {
    if (_draftRoomId != room.id) {
      _applyRoomConfigToDraft(room);
      _hasOptimisticConfig = false;
      _configDirty = false;
      _configSyncPending = false;
      return;
    }

    if (_hasOptimisticConfig) {
      if (_roomMatchesDraft(room)) {
        _applyRoomConfigToDraft(room);
        _hasOptimisticConfig = false;
      }
      return;
    }

    _applyRoomConfigToDraft(room);
  }

  void _applyRoomConfigToDraft(OnlineRoom room) {
    _draftRoomId = room.id;
    _draftCategories = List<WordCategory>.from(room.categories);
    _draftHintsEnabled = room.hintsEnabled;
    _draftImpostorCount = room.impostorCount;
    _draftDurationSeconds = room.durationSeconds;
  }

  bool _roomMatchesDraft(OnlineRoom room) {
    return _sameCategories(room.categories, _draftCategories ?? room.categories) &&
        room.hintsEnabled == (_draftHintsEnabled ?? room.hintsEnabled) &&
        room.impostorCount == (_draftImpostorCount ?? room.impostorCount) &&
        room.durationSeconds == (_draftDurationSeconds ?? room.durationSeconds);
  }

  bool _sameCategories(
    List<WordCategory> left,
    List<WordCategory> right,
  ) {
    if (left.length != right.length) return false;
    final leftNames = left.map((category) => category.name).toList()..sort();
    final rightNames = right.map((category) => category.name).toList()..sort();
    return listEquals(leftNames, rightNames);
  }

  List<WordCategory> _currentCategories(OnlineRoom room) =>
      List<WordCategory>.from(_draftCategories ?? room.categories);

  bool _currentHintsEnabled(OnlineRoom room) =>
      _draftHintsEnabled ?? room.hintsEnabled;

  int _currentImpostorCount(OnlineRoom room) =>
      _draftImpostorCount ?? room.impostorCount;

  int _currentDurationSeconds(OnlineRoom room) =>
      _draftDurationSeconds ?? room.durationSeconds;

  void _scheduleRoomConfigSync(
    OnlineRoom room,
    List<OnlineRoomPlayer> players,
  ) {
    _configDebounceTimer?.cancel();
    _configDebounceTimer = Timer(
      const Duration(milliseconds: 220),
      () => _flushRoomConfig(room, players),
    );
  }

  Future<void> _flushRoomConfig(
    OnlineRoom room,
    List<OnlineRoomPlayer> players,
  ) async {
    if (_configRequestInFlight || !_configDirty) return;

    final selectedCategories = _currentCategories(room);
    if (selectedCategories.isEmpty) {
      _showSnackBar('Debes dejar al menos una categoria activa.');
      return;
    }

    final maxImpostors = (players.length / 3).floor().clamp(1, 3);
    final impostorCount = _currentImpostorCount(room).clamp(1, maxImpostors);
    final durationSeconds = _currentDurationSeconds(room).clamp(60, 900);
    final hintsEnabled = _currentHintsEnabled(room);

    _configRequestInFlight = true;
    _configSyncPending = false;
    var completedWithoutError = false;
    if (mounted) {
      setState(() {});
    }

    try {
      await ref.read(onlineRoomsRepositoryProvider).updateRoomConfig(
            roomId: room.id,
            categories: selectedCategories,
            hintsEnabled: hintsEnabled,
            impostorCount: impostorCount,
            durationSeconds: durationSeconds,
          );
      await ref.read(onlineLobbySyncProvider(widget.roomId))?.broadcastConfigUpdated(
            categories: selectedCategories,
            hintsEnabled: hintsEnabled,
            impostorCount: impostorCount,
            durationSeconds: durationSeconds,
          );
      completedWithoutError = true;
    } catch (e) {
      _hasOptimisticConfig = false;
      _configDirty = false;
      ref.invalidate(onlineRoomProvider(widget.roomId));
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      final hasQueuedChanges = _configSyncPending;
      if (completedWithoutError) {
        _configDirty = hasQueuedChanges;
      }
      _configRequestInFlight = false;
      if (hasQueuedChanges) {
        _scheduleRoomConfigSync(room, players);
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _toggleReady({
    required String roomId,
    required bool nextValue,
  }) async {
    if (_busyReady) return;

    setState(() => _busyReady = true);

    try {
      await ref.read(onlineRoomsRepositoryProvider).setReady(
            roomId: roomId,
            isReady: nextValue,
          );
      _refreshLobbyProviders();
      await ref
          .read(onlineLobbySyncProvider(widget.roomId))
          ?.broadcastReadyUpdated(isReady: nextValue);
    } catch (e) {
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busyReady = false);
      }
    }
  }

  void _updateRoomConfig(
    OnlineRoom room,
    List<OnlineRoomPlayer> players, {
    List<WordCategory>? categories,
    bool? hintsEnabled,
    int? impostorCount,
    int? durationSeconds,
  }) {
    final selectedCategories = categories ?? _currentCategories(room);
    if (selectedCategories.isEmpty) {
      _showSnackBar('Debes dejar al menos una categoria activa.');
      return;
    }

    final maxImpostors = ((players.length) / 3).floor().clamp(1, 3);
    final nextImpostorCount = (impostorCount ?? _currentImpostorCount(room))
        .clamp(1, maxImpostors);

    setState(() {
      _draftRoomId = room.id;
      _draftCategories = List<WordCategory>.from(selectedCategories);
      _draftHintsEnabled = hintsEnabled ?? _currentHintsEnabled(room);
      _draftImpostorCount = nextImpostorCount;
      _draftDurationSeconds = durationSeconds ?? _currentDurationSeconds(room);
      _hasOptimisticConfig = true;
      _configDirty = true;
      _configSyncPending = true;
    });

    _scheduleRoomConfigSync(room, players);
  }

  Future<void> _leaveRoom() async {
    if (_leaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Salir de la sala',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Saldras del lobby actual. Si eras el host, la sala pasara al siguiente jugador.',
          style: GoogleFonts.nunito(color: AppTheme.textSecondary),
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

    setState(() => _leaving = true);

    try {
      await ref.read(onlineRoomsRepositoryProvider).leaveRoom(widget.roomId);
      if (mounted) {
        context.go('/online');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
      }
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSnackBar('Codigo copiado: $code');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.nunito())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(onlineProfileProvider);
    ref.watch(onlineLobbySyncProvider(widget.roomId));
    final roomAsync = ref.watch(onlineRoomProvider(widget.roomId));
    final playersAsync = ref.watch(onlineRoomPlayersProvider(widget.roomId));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackAttempt();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _leaving ? null : _handleBackAttempt,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Lobby privado',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              onPressed: _leaving ? null : _handleBackAttempt,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Salir de la sala',
            ),
          ],
        ),
        body: profileAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () {
            if (_lastProfile != null && _lastRoom != null && _lastPlayers != null) {
              return _buildLobbyContent(
                _lastProfile!,
                _lastRoom!,
                _lastPlayers!,
              );
            }
            return _buildLoadingState();
          },
          error: (_, __) => _buildCenteredMessage(
            title: 'No pudimos cargar tu perfil online',
            subtitle: 'Vuelve al inicio online y prueba otra vez.',
          ),
          data: (profile) {
            if (profile == null || !profile.hasDisplayName) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.go('/online/display-name');
                }
              });
              return const SizedBox.shrink();
            }

            _lastProfile = profile;

            return roomAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () {
                if (_lastRoom != null && _lastPlayers != null) {
                  return _buildLobbyContent(
                    profile,
                    _lastRoom!,
                    _lastPlayers!,
                  );
                }
                return _buildLoadingState();
              },
              error: (_, __) => _buildCenteredMessage(
                title: 'No pudimos cargar la sala',
                subtitle:
                    'Puede que todavia no existan las tablas online o que la sala ya no este disponible.',
              ),
              data: (room) {
                if (room == null) {
                  return _buildCenteredMessage(
                    title: 'La sala ya no existe',
                    subtitle: 'Parece que fue cerrada o eliminada.',
                  );
                }

                _lastRoom = room;

                return playersAsync.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () {
                    if (_lastPlayers != null) {
                      return _buildLobbyContent(profile, room, _lastPlayers!);
                    }
                    return _buildLoadingState();
                  },
                  error: (_, __) => _buildCenteredMessage(
                    title: 'No pudimos cargar los jugadores',
                    subtitle: 'Intenta salir y volver a entrar a la sala.',
                  ),
                  data: (players) {
                    _lastPlayers = players;
                    return _buildLobbyContent(profile, room, players);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLobbyContent(
    OnlineProfile profile,
    OnlineRoom room,
    List<OnlineRoomPlayer> players,
  ) {
    final currentPlayer = _findPlayer(players, profile.id);
    if (currentPlayer == null) {
      return _buildCenteredMessage(
        title: 'No encontramos tu jugador en la sala',
        subtitle:
            'Puede que todavia se este sincronizando o que ya no formes parte del lobby.',
      );
    }

    _syncDraftConfigFromRoom(room);

    final isHost = currentPlayer.isHost;
    final readyCount = players.where((player) => player.isReady).length;
    final canStartVisual =
        players.length >= room.minPlayers && readyCount >= room.minPlayers;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCodeCard(room),
            const SizedBox(height: 18),
            _buildStatusCard(room, players, readyCount),
            const SizedBox(height: 18),
            _buildReadyCard(room, currentPlayer),
            const SizedBox(height: 18),
            _buildConfigCard(
              room: room,
              players: players,
              isHost: isHost,
            ),
            const SizedBox(height: 18),
            _buildPlayersSection(players),
            const SizedBox(height: 18),
            _buildStartPlaceholder(canStartVisual, isHost),
          ],
        ),
      ),
    );
  }

  OnlineRoomPlayer? _findPlayer(List<OnlineRoomPlayer> players, String userId) {
    for (final player in players) {
      if (player.userId == userId) {
        return player;
      }
    }
    return null;
  }

  Widget _buildCodeCard(OnlineRoom room) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Codigo de sala',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  room.code,
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyCode(room.code),
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copiar codigo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    OnlineRoom room,
    List<OnlineRoomPlayer> players,
    int readyCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del lobby',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _lobbyStat('Modo', room.gameMode.displayName),
          _lobbyStat('Jugadores', '${players.length}/${room.maxPlayers}'),
          _lobbyStat('Listos', '$readyCount/${players.length}'),
          _lobbyStat('Minimo para empezar', '${room.minPlayers}'),
        ],
      ),
    );
  }

  Widget _buildReadyCard(OnlineRoom room, OnlineRoomPlayer currentPlayer) {
    final isHost = currentPlayer.isHost;
    final title = currentPlayer.isReady
        ? 'Ya estas listo'
        : 'Marca que estas listo';
    final subtitle = isHost
        ? 'Como host quedas listo por defecto y puedes seguir configurando la sala.'
        : currentPlayer.isReady
            ? 'Puedes esperar mientras el host termina de configurar la sala.'
            : 'Activa tu estado cuando estes listo para empezar.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: currentPlayer.isReady
            ? AppTheme.successColor.withValues(alpha: 0.10)
            : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: currentPlayer.isReady
              ? AppTheme.successColor.withValues(alpha: 0.25)
              : AppTheme.textSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isHost) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _busyReady
                  ? null
                  : () => _toggleReady(
                        roomId: room.id,
                        nextValue: !currentPlayer.isReady,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPlayer.isReady
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
              ),
              child: Text(currentPlayer.isReady ? 'Quitar' : 'Listo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required OnlineRoom room,
    required List<OnlineRoomPlayer> players,
    required bool isHost,
  }) {
    final selectedCategories = _currentCategories(room);
    final selectedHintsEnabled = _currentHintsEnabled(room);
    final selectedImpostorCount = _currentImpostorCount(room);
    final selectedDurationSeconds = _currentDurationSeconds(room);
    final maxImpostors = (players.length / 3).floor().clamp(1, 3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Configuracion de la sala',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isHost)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Host',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _lobbyStat('Modo online actual', 'Modo Clasico'),
          _lobbyStat(
            'Duracion seleccionada',
            _formatDuration(selectedDurationSeconds),
          ),
          const SizedBox(height: 14),
          Text(
            'Duracion',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationOptions.map((seconds) {
              final selected = selectedDurationSeconds == seconds;
              return ChoiceChip(
                label: Text(_formatDurationChip(seconds)),
                selected: selected,
                onSelected: !isHost
                    ? null
                    : (_) => _updateRoomConfig(
                          room,
                          players,
                          durationSeconds: seconds,
                        ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.surfaceColor,
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: selectedDurationSeconds.toDouble(),
              min: 60,
              max: 900,
              divisions: 84,
              onChanged: !isHost
                  ? null
                  : (value) => _updateRoomConfig(
                        room,
                        players,
                        durationSeconds: value.round(),
                      ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pistas para impostores',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: selectedHintsEnabled,
                onChanged: !isHost
                    ? null
                    : (value) => _updateRoomConfig(
                          room,
                          players,
                          hintsEnabled: value,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cantidad de impostores',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: !isHost || selectedImpostorCount <= 1
                    ? null
                    : () => _updateRoomConfig(
                          room,
                          players,
                          impostorCount: selectedImpostorCount - 1,
                        ),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text(
                '$selectedImpostorCount',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                onPressed: !isHost || selectedImpostorCount >= maxImpostors
                        ? null
                        : () => _updateRoomConfig(
                              room,
                              players,
                              impostorCount: selectedImpostorCount + 1,
                            ),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Categorias activas',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WordCategory.values.map((category) {
              final selected = selectedCategories.contains(category);
              return FilterChip(
                label: Text(category.displayName),
                selected: selected,
                onSelected: !isHost
                    ? null
                    : (value) {
                        final nextCategories = selectedCategories.toList();
                        if (value) {
                          if (!nextCategories.contains(category)) {
                            nextCategories.add(category);
                          }
                        } else {
                          nextCategories.remove(category);
                        }
                        _updateRoomConfig(
                          room,
                          players,
                          categories: nextCategories,
                        );
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSection(List<OnlineRoomPlayer> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jugadores',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...players.map(_buildPlayerTile),
      ],
    );
  }

  Widget _buildPlayerTile(OnlineRoomPlayer player) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.displayName.characters.first.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.isConnected ? 'Conectado' : 'Desconectado',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: player.isConnected
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (player.isHost) _badge('Host', AppTheme.primaryColor),
          const SizedBox(width: 6),
          _badge(
            player.isReady ? 'Listo' : 'Esperando',
            player.isReady ? AppTheme.successColor : AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStartPlaceholder(bool canStartVisual, bool isHost) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Siguiente paso del MVP',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHost
                ? 'La creacion del match autoritativo y el boton real de iniciar partida llegan en el siguiente bloque de Fase 3/4.'
                : 'El host podra iniciar la partida cuando el motor online este conectado.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                canStartVisual
                    ? 'Comenzar partida (proximamente)'
                    : 'Faltan jugadores listos',
              ),
            ),
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

  Widget _lobbyStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
    );
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
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes min';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
  }

  String _formatDurationChip(int seconds) {
    if (seconds % 60 == 0) {
      return '${seconds ~/ 60} min';
    }
    return '${seconds}s';
  }
}
