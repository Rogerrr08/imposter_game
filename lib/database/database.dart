import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

/// Groups of players that can be reused across games.
class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Players that belong to a [Groups] entry.
class GroupPlayers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  TextColumn get name => text()();
}

/// Record of a completed game.
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id).nullable()();
  TextColumn get category => text()();
  TextColumn get word => text()();
  IntColumn get duration => integer()();
  IntColumn get impostorCount => integer()();
  BoolColumn get hintsEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get civilsWon => boolean()();
  BoolColumn get impostorGuessedWord =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Individual player results inside a [Games] entry.
class GamePlayersTable extends Table {
  @override
  String get actualTableName => 'game_players';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId => integer().references(Games, #id)();
  TextColumn get playerName => text()();
  BoolColumn get wasImpostor => boolean()();
  IntColumn get points => integer().withDefault(const Constant(0))();
  BoolColumn get wasEliminated =>
      boolean().withDefault(const Constant(false))();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [Groups, GroupPlayers, Games, GamePlayersTable],
  daos: [GroupDao, GameDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'impostor_game',
      native: const DriftNativeOptions(shareAcrossIsolates: true),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DAOs
// ---------------------------------------------------------------------------

@DriftAccessor(tables: [Groups, GroupPlayers])
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  // ---- Groups ----

  /// Insert a new group and return the generated row.
  Future<Group> createGroup(String name) async {
    final id = await into(groups).insert(
      GroupsCompanion.insert(name: name),
    );
    return (select(groups)..where((g) => g.id.equals(id))).getSingle();
  }

  /// Return every group ordered by creation date (newest first).
  Future<List<Group>> getAllGroups() {
    return (select(groups)..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .get();
  }

  /// Stream of all groups ordered by creation date (newest first).
  Stream<List<Group>> watchAllGroups() {
    return (select(groups)..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  /// Get a single group by its [id].
  Future<Group> getGroupById(int id) {
    return (select(groups)..where((g) => g.id.equals(id))).getSingle();
  }

  /// Update the name of an existing group.
  Future<bool> updateGroupName(int id, String newName) {
    return (update(groups)..where((g) => g.id.equals(id)))
        .write(GroupsCompanion(name: Value(newName)))
        .then((rows) => rows > 0);
  }

  /// Delete a group and all of its players (cascade manually).
  Future<void> deleteGroup(int id) async {
    await (delete(groupPlayers)..where((p) => p.groupId.equals(id))).go();
    await (delete(groups)..where((g) => g.id.equals(id))).go();
  }

  // ---- Group players ----

  /// Add a player to a group and return the generated row.
  Future<GroupPlayer> addPlayerToGroup(int groupId, String playerName) async {
    final id = await into(groupPlayers).insert(
      GroupPlayersCompanion.insert(groupId: groupId, name: playerName),
    );
    return (select(groupPlayers)..where((p) => p.id.equals(id))).getSingle();
  }

  /// Remove a player from a group.
  Future<void> removePlayerFromGroup(int playerId) {
    return (delete(groupPlayers)..where((p) => p.id.equals(playerId))).go();
  }

  /// Get all players that belong to [groupId].
  Future<List<GroupPlayer>> getPlayersInGroup(int groupId) {
    return (select(groupPlayers)..where((p) => p.groupId.equals(groupId)))
        .get();
  }

  /// Stream of players for a given group.
  Stream<List<GroupPlayer>> watchPlayersInGroup(int groupId) {
    return (select(groupPlayers)..where((p) => p.groupId.equals(groupId)))
        .watch();
  }

  /// Update the name of an existing player.
  Future<bool> updatePlayerName(int playerId, String newName) {
    return (update(groupPlayers)..where((p) => p.id.equals(playerId)))
        .write(GroupPlayersCompanion(name: Value(newName)))
        .then((rows) => rows > 0);
  }
}

@DriftAccessor(tables: [Games, GamePlayersTable, Groups])
class GameDao extends DatabaseAccessor<AppDatabase> with _$GameDaoMixin {
  GameDao(super.db);

  /// Persist a completed game together with all its player results.
  ///
  /// Returns the generated game id.
  Future<int> saveGame({
    required int? groupId,
    required String category,
    required String word,
    required int duration,
    required int impostorCount,
    required bool hintsEnabled,
    required bool civilsWon,
    required bool impostorGuessedWord,
    required List<GamePlayerEntry> playerResults,
  }) async {
    return transaction(() async {
      final gameId = await into(games).insert(
        GamesCompanion.insert(
          groupId: Value(groupId),
          category: category,
          word: word,
          duration: duration,
          impostorCount: impostorCount,
          hintsEnabled: Value(hintsEnabled),
          civilsWon: civilsWon,
          impostorGuessedWord: Value(impostorGuessedWord),
        ),
      );

      for (final player in playerResults) {
        await into(gamePlayersTable).insert(
          GamePlayersTableCompanion.insert(
            gameId: gameId,
            playerName: player.playerName,
            wasImpostor: player.wasImpostor,
            points: Value(player.points),
            wasEliminated: Value(player.wasEliminated),
          ),
        );
      }

      return gameId;
    });
  }

  /// Get all games for a given group ordered by most recent first.
  Future<List<Game>> getGamesForGroup(int groupId) {
    return (select(games)
          ..where((g) => g.groupId.equals(groupId))
          ..orderBy([(g) => OrderingTerm.desc(g.playedAt)]))
        .get();
  }

  /// Get games for a group filtered by [category].
  Future<List<Game>> getGamesForGroupByCategory(
      int groupId, String category) {
    return (select(games)
          ..where(
              (g) => g.groupId.equals(groupId) & g.category.equals(category))
          ..orderBy([(g) => OrderingTerm.desc(g.playedAt)]))
        .get();
  }

  /// Aggregate ranking for a group: total points per player, sorted
  /// descending.
  Future<List<PlayerRanking>> getRankingForGroup(int groupId) async {
    final query = customSelect(
      'SELECT gp.player_name AS name, SUM(gp.points) AS total_points, COUNT(DISTINCT gp.game_id) AS games_played '
      'FROM game_players gp '
      'INNER JOIN games g ON gp.game_id = g.id '
      'WHERE g.group_id = ? '
      'GROUP BY gp.player_name '
      'ORDER BY total_points DESC',
      variables: [Variable.withInt(groupId)],
      readsFrom: {games, gamePlayersTable},
    );

    final rows = await query.get();
    return rows
        .map((row) => PlayerRanking(
              playerName: row.read<String>('name'),
              totalPoints: row.read<int>('total_points'),
              gamesPlayed: row.read<int>('games_played'),
            ))
        .toList();
  }

  /// Aggregate ranking for a group filtered by [category].
  Future<List<PlayerRanking>> getRankingForGroupByCategory(
      int groupId, String category) async {
    final query = customSelect(
      'SELECT gp.player_name AS name, SUM(gp.points) AS total_points, COUNT(DISTINCT gp.game_id) AS games_played '
      'FROM game_players gp '
      'INNER JOIN games g ON gp.game_id = g.id '
      'WHERE g.group_id = ? AND g.category = ? '
      'GROUP BY gp.player_name '
      'ORDER BY total_points DESC',
      variables: [Variable.withInt(groupId), Variable.withString(category)],
      readsFrom: {games, gamePlayersTable},
    );

    final rows = await query.get();
    return rows
        .map((row) => PlayerRanking(
              playerName: row.read<String>('name'),
              totalPoints: row.read<int>('total_points'),
              gamesPlayed: row.read<int>('games_played'),
            ))
        .toList();
  }

  /// Full details for a single game, including all player entries.
  Future<GameDetails> getGameDetails(int gameId) async {
    final game =
        await (select(games)..where((g) => g.id.equals(gameId))).getSingle();
    final players = await (select(gamePlayersTable)
          ..where((p) => p.gameId.equals(gameId)))
        .get();

    return GameDetails(game: game, players: players);
  }

  /// Stream of game details for reactive UI updates.
  Stream<GameDetails> watchGameDetails(int gameId) {
    final gameStream =
        (select(games)..where((g) => g.id.equals(gameId))).watchSingle();
    final playersStream = (select(gamePlayersTable)
          ..where((p) => p.gameId.equals(gameId)))
        .watch();

    return gameStream.asyncMap((game) async {
      final players = await (select(gamePlayersTable)
            ..where((p) => p.gameId.equals(gameId)))
          .get();
      return GameDetails(game: game, players: players);
    });
  }
}

// ---------------------------------------------------------------------------
// Helper data classes used by GameDao
// ---------------------------------------------------------------------------

/// Input data for a single player result when saving a game.
class GamePlayerEntry {
  final String playerName;
  final bool wasImpostor;
  final int points;
  final bool wasEliminated;

  const GamePlayerEntry({
    required this.playerName,
    required this.wasImpostor,
    required this.points,
    required this.wasEliminated,
  });
}

/// Aggregate ranking row.
class PlayerRanking {
  final String playerName;
  final int totalPoints;
  final int gamesPlayed;

  const PlayerRanking({
    required this.playerName,
    required this.totalPoints,
    required this.gamesPlayed,
  });
}

/// A game together with all its player results.
class GameDetails {
  final Game game;
  final List<GamePlayersTableData> players;

  const GameDetails({
    required this.game,
    required this.players,
  });
}
