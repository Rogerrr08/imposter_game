import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/word_bank.dart';
import '../domain/online_room.dart';
import 'online_auth_provider.dart';
import 'online_lobby_sync_provider.dart';
import 'online_rooms_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class RoomLobbyState {
  final OnlineProfile? profile;
  final OnlineRoom? room;
  final List<OnlineRoomPlayer> players;
  final OnlineRoomPlayer? currentPlayer;

  // Draft config (optimistic)
  final List<WordCategory> draftCategories;
  final bool draftHintsEnabled;
  final int draftImpostorCount;
  final int draftDurationSeconds;
  final bool hasOptimisticConfig;

  // Action flags
  final bool isBusyReady;
  final bool isLeaving;
  final bool isConfigSyncing;
  final String? error;

  const RoomLobbyState({
    this.profile,
    this.room,
    this.players = const [],
    this.currentPlayer,
    this.draftCategories = const [],
    this.draftHintsEnabled = true,
    this.draftImpostorCount = 1,
    this.draftDurationSeconds = 120,
    this.hasOptimisticConfig = false,
    this.isBusyReady = false,
    this.isLeaving = false,
    this.isConfigSyncing = false,
    this.error,
  });

  bool get isHost => currentPlayer?.isHost ?? false;
  bool get isReady => currentPlayer?.isReady ?? false;
  int get readyCount => players.where((p) => p.isReady).length;
  int get maxImpostors => (players.length / 3).floor().clamp(1, 3);

  bool get canStartVisual =>
      room != null &&
      players.length >= room!.minPlayers &&
      readyCount >= room!.minPlayers;

  int get missingReady =>
      room != null
          ? (room!.minPlayers - readyCount).clamp(0, room!.minPlayers)
          : 0;

  int get missingPlayers =>
      room != null
          ? (room!.minPlayers - players.length).clamp(0, room!.minPlayers)
          : 0;

  RoomLobbyState copyWith({
    OnlineProfile? profile,
    OnlineRoom? room,
    List<OnlineRoomPlayer>? players,
    OnlineRoomPlayer? currentPlayer,
    List<WordCategory>? draftCategories,
    bool? draftHintsEnabled,
    int? draftImpostorCount,
    int? draftDurationSeconds,
    bool? hasOptimisticConfig,
    bool? isBusyReady,
    bool? isLeaving,
    bool? isConfigSyncing,
    String? error,
    bool clearError = false,
    bool clearCurrentPlayer = false,
  }) {
    return RoomLobbyState(
      profile: profile ?? this.profile,
      room: room ?? this.room,
      players: players ?? this.players,
      currentPlayer: clearCurrentPlayer
          ? currentPlayer
          : (currentPlayer ?? this.currentPlayer),
      draftCategories: draftCategories ?? this.draftCategories,
      draftHintsEnabled: draftHintsEnabled ?? this.draftHintsEnabled,
      draftImpostorCount: draftImpostorCount ?? this.draftImpostorCount,
      draftDurationSeconds: draftDurationSeconds ?? this.draftDurationSeconds,
      hasOptimisticConfig: hasOptimisticConfig ?? this.hasOptimisticConfig,
      isBusyReady: isBusyReady ?? this.isBusyReady,
      isLeaving: isLeaving ?? this.isLeaving,
      isConfigSyncing: isConfigSyncing ?? this.isConfigSyncing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final roomLobbyNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<RoomLobbyNotifier, RoomLobbyState, String>(
  (roomId) => RoomLobbyNotifier(roomId),
);

class RoomLobbyNotifier extends AsyncNotifier<RoomLobbyState> {
  RoomLobbyNotifier(this._roomId);

  final String _roomId;
  Timer? _configDebounceTimer;
  bool _configRequestInFlight = false;
  bool _configSyncPending = false;
  bool _configDirty = false;
  String? _draftRoomId;

  @override
  Future<RoomLobbyState> build() async {
    ref.onDispose(() {
      _configDebounceTimer?.cancel();
    });

    // Watch the lobby sync provider so the channel stays alive
    ref.watch(onlineLobbySyncProvider(_roomId));

    final profile = await ref.watch(onlineProfileProvider.future);
    final room = await ref.watch(onlineRoomProvider(_roomId).future);
    final players = await ref.watch(onlineRoomPlayersProvider(_roomId).future);

    if (profile == null || room == null) {
      return RoomLobbyState(profile: profile, room: room, players: players);
    }

    final currentPlayer = _findPlayer(players, profile.id);

    // Reconcile draft config with server state
    final prev = state.value;
    var draftCategories = prev?.draftCategories ?? room.categories;
    var draftHints = prev?.draftHintsEnabled ?? room.hintsEnabled;
    var draftImpostors = prev?.draftImpostorCount ?? room.impostorCount;
    var draftDuration = prev?.draftDurationSeconds ?? room.durationSeconds;
    var hasOptimistic = prev?.hasOptimisticConfig ?? false;

    if (_draftRoomId != room.id) {
      // First load or room changed
      _applyRoomDraft(room);
      draftCategories = room.categories;
      draftHints = room.hintsEnabled;
      draftImpostors = room.impostorCount;
      draftDuration = room.durationSeconds;
      hasOptimistic = false;
      _configDirty = false;
      _configSyncPending = false;
    } else if (hasOptimistic) {
      // Check if server caught up
      if (_roomMatchesDraft(
        room,
        draftCategories,
        draftHints,
        draftImpostors,
        draftDuration,
      )) {
        draftCategories = room.categories;
        draftHints = room.hintsEnabled;
        draftImpostors = room.impostorCount;
        draftDuration = room.durationSeconds;
        hasOptimistic = false;
      }
    } else {
      // No optimistic state — follow the server
      draftCategories = room.categories;
      draftHints = room.hintsEnabled;
      draftImpostors = room.impostorCount;
      draftDuration = room.durationSeconds;
    }

    return RoomLobbyState(
      profile: profile,
      room: room,
      players: players,
      currentPlayer: currentPlayer,
      draftCategories: List<WordCategory>.from(draftCategories),
      draftHintsEnabled: draftHints,
      draftImpostorCount: draftImpostors,
      draftDurationSeconds: draftDuration,
      hasOptimisticConfig: hasOptimistic,
      isBusyReady: prev?.isBusyReady ?? false,
      isLeaving: prev?.isLeaving ?? false,
      isConfigSyncing: _configRequestInFlight,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Toggle ready / unready for the current player.
  Future<void> toggleReady() async {
    final s = state.value;
    if (s == null || s.isBusyReady || s.room == null || s.currentPlayer == null) {
      return;
    }

    final nextValue = !s.currentPlayer!.isReady;
    state = AsyncData(s.copyWith(isBusyReady: true, clearError: true));

    try {
      await ref.read(onlineRoomsRepositoryProvider).setReady(
            roomId: s.room!.id,
            isReady: nextValue,
          );
      ref.invalidate(onlineRoomProvider(_roomId));
      ref.invalidate(onlineRoomPlayersProvider(_roomId));
      await ref
          .read(onlineLobbySyncProvider(_roomId))
          ?.broadcastReadyUpdated(isReady: nextValue);
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isBusyReady: false));
      }
    }
  }

  /// Update room config with optimistic draft + debounced sync.
  void updateConfig({
    List<WordCategory>? categories,
    bool? hintsEnabled,
    int? impostorCount,
    int? durationSeconds,
  }) {
    final s = state.value;
    if (s == null || s.room == null) return;

    final nextCategories = categories ??
        List<WordCategory>.from(s.draftCategories);
    if (nextCategories.isEmpty) {
      _setError('Debes dejar al menos una categoria activa.');
      return;
    }

    final maxImp = s.maxImpostors;
    final nextImpostors = (impostorCount ?? s.draftImpostorCount)
        .clamp(1, maxImp);

    state = AsyncData(s.copyWith(
      draftCategories: List<WordCategory>.from(nextCategories),
      draftHintsEnabled: hintsEnabled ?? s.draftHintsEnabled,
      draftImpostorCount: nextImpostors,
      draftDurationSeconds: durationSeconds ?? s.draftDurationSeconds,
      hasOptimisticConfig: true,
      clearError: true,
    ));

    _draftRoomId = s.room!.id;
    _configDirty = true;
    _configSyncPending = true;
    _scheduleConfigFlush();
  }

  /// Leave the room. Returns true if the leave succeeded.
  Future<bool> leaveRoom() async {
    final s = state.value;
    if (s == null || s.isLeaving || s.room == null) return false;

    state = AsyncData(s.copyWith(isLeaving: true, clearError: true));

    try {
      await ref.read(onlineRoomsRepositoryProvider).leaveRoom(_roomId);
      return true;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isLeaving: false));
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _scheduleConfigFlush() {
    _configDebounceTimer?.cancel();
    _configDebounceTimer = Timer(
      const Duration(milliseconds: 220),
      _flushConfig,
    );
  }

  Future<void> _flushConfig() async {
    if (_configRequestInFlight || !_configDirty) return;

    final s = state.value;
    if (s == null || s.room == null) return;

    final categories = s.draftCategories;
    if (categories.isEmpty) return;

    final impostors = s.draftImpostorCount.clamp(1, s.maxImpostors);
    final duration = s.draftDurationSeconds.clamp(60, 900);
    final hints = s.draftHintsEnabled;

    _configRequestInFlight = true;
    _configSyncPending = false;
    state = AsyncData(s.copyWith(isConfigSyncing: true));

    var completedOk = false;

    try {
      await ref.read(onlineRoomsRepositoryProvider).updateRoomConfig(
            roomId: s.room!.id,
            categories: categories,
            hintsEnabled: hints,
            impostorCount: impostors,
            durationSeconds: duration,
          );
      await ref
          .read(onlineLobbySyncProvider(_roomId))
          ?.broadcastConfigUpdated(
            categories: categories,
            hintsEnabled: hints,
            impostorCount: impostors,
            durationSeconds: duration,
          );
      completedOk = true;
    } catch (e) {
      // Rollback optimistic state
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(hasOptimisticConfig: false));
      }
      _configDirty = false;
      ref.invalidate(onlineRoomProvider(_roomId));
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      final hasQueued = _configSyncPending;
      if (completedOk) {
        _configDirty = hasQueued;
      }
      _configRequestInFlight = false;

      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isConfigSyncing: false));
      }

      if (hasQueued) {
        _scheduleConfigFlush();
      }
    }
  }

  void _applyRoomDraft(OnlineRoom room) {
    _draftRoomId = room.id;
  }

  bool _roomMatchesDraft(
    OnlineRoom room,
    List<WordCategory> categories,
    bool hints,
    int impostors,
    int duration,
  ) {
    return _sameCategories(room.categories, categories) &&
        room.hintsEnabled == hints &&
        room.impostorCount == impostors &&
        room.durationSeconds == duration;
  }

  static bool _sameCategories(
    List<WordCategory> left,
    List<WordCategory> right,
  ) {
    if (left.length != right.length) return false;
    final leftNames = left.map((c) => c.name).toList()..sort();
    final rightNames = right.map((c) => c.name).toList()..sort();
    return listEquals(leftNames, rightNames);
  }

  static OnlineRoomPlayer? _findPlayer(
    List<OnlineRoomPlayer> players,
    String userId,
  ) {
    for (final player in players) {
      if (player.userId == userId) return player;
    }
    return null;
  }

  void _setError(String message) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(error: message));
    }
  }
}
