import '../../../data/word_bank.dart';
import '../../../models/game_state.dart';

enum OnlineRoomStatus {
  waiting,
  playing,
  finished;

  static OnlineRoomStatus fromValue(String value) {
    switch (value) {
      case 'playing':
        return OnlineRoomStatus.playing;
      case 'finished':
        return OnlineRoomStatus.finished;
      case 'waiting':
      default:
        return OnlineRoomStatus.waiting;
    }
  }
}

class OnlineRoom {
  final String id;
  final String code;
  final String hostUserId;
  final OnlineRoomStatus status;
  final GameMode gameMode;
  final List<WordCategory> categories;
  final bool hintsEnabled;
  final int impostorCount;
  final int durationSeconds;
  final int minPlayers;
  final int maxPlayers;
  final DateTime createdAt;
  final DateTime? startedAt;

  const OnlineRoom({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.status,
    required this.gameMode,
    required this.categories,
    required this.hintsEnabled,
    required this.impostorCount,
    required this.durationSeconds,
    required this.minPlayers,
    required this.maxPlayers,
    required this.createdAt,
    this.startedAt,
  });

  factory OnlineRoom.fromMap(Map<String, dynamic> map) {
    final rawCategories = (map['categories'] as List<dynamic>? ?? const [])
        .map((entry) => entry.toString())
        .toList();

    return OnlineRoom(
      id: map['id'] as String,
      code: map['code'] as String,
      hostUserId: map['host_user_id'] as String,
      status: OnlineRoomStatus.fromValue(map['status'] as String? ?? 'waiting'),
      gameMode: _parseGameMode(map['game_mode'] as String?),
      categories: rawCategories
          .map(_parseWordCategory)
          .whereType<WordCategory>()
          .toList(),
      hintsEnabled: map['hints_enabled'] as bool? ?? true,
      impostorCount: map['impostor_count'] as int? ?? 1,
      durationSeconds: map['duration_seconds'] as int? ?? 120,
      minPlayers: map['min_players'] as int? ?? 4,
      maxPlayers: map['max_players'] as int? ?? 8,
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] == null
          ? null
          : DateTime.parse(map['started_at'] as String),
    );
  }

  bool get canStartConfiguration => status == OnlineRoomStatus.waiting;

  static GameMode _parseGameMode(String? value) {
    switch (value) {
      case 'classic':
        return GameMode.classic;
      case 'express':
        return GameMode.express;
      default:
        return GameMode.classic;
    }
  }

  static WordCategory? _parseWordCategory(String value) {
    for (final category in WordCategory.values) {
      if (category.name == value) {
        return category;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineRoom &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          hostUserId == other.hostUserId &&
          status == other.status &&
          gameMode == other.gameMode &&
          hintsEnabled == other.hintsEnabled &&
          impostorCount == other.impostorCount &&
          durationSeconds == other.durationSeconds &&
          minPlayers == other.minPlayers &&
          maxPlayers == other.maxPlayers;

  @override
  int get hashCode => Object.hash(
        id,
        code,
        hostUserId,
        status,
        gameMode,
        hintsEnabled,
        impostorCount,
        durationSeconds,
        minPlayers,
        maxPlayers,
      );
}

class OnlineRoomPlayer {
  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int seatOrder;
  final bool isHost;
  final bool isReady;
  final bool isConnected;
  final DateTime? lastSeenAt;
  final DateTime joinedAt;

  const OnlineRoomPlayer({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.seatOrder,
    required this.isHost,
    required this.isReady,
    required this.isConnected,
    this.lastSeenAt,
    required this.joinedAt,
  });

  factory OnlineRoomPlayer.fromMap(Map<String, dynamic> map) {
    return OnlineRoomPlayer(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      seatOrder: map['seat_order'] as int? ?? 0,
      isHost: map['is_host'] as bool? ?? false,
      isReady: map['is_ready'] as bool? ?? false,
      isConnected: map['is_connected'] as bool? ?? true,
      lastSeenAt: map['last_seen_at'] == null
          ? null
          : DateTime.parse(map['last_seen_at'] as String),
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineRoomPlayer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          displayName == other.displayName &&
          seatOrder == other.seatOrder &&
          isHost == other.isHost &&
          isReady == other.isReady &&
          isConnected == other.isConnected;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        displayName,
        seatOrder,
        isHost,
        isReady,
        isConnected,
      );
}
