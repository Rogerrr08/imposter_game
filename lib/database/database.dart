import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

const _overallStatsScope = '__all__';
const _playerStatsInitializedKey = 'player_stats_initialized';

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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createAuxiliaryTables();
          await _createAuxiliaryIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            await _createAuxiliaryTables();
            await _createAuxiliaryIndexes();
          }
        },
        beforeOpen: (details) async {
          await _createAuxiliaryTables();
          await _createAuxiliaryIndexes();
          await _ensurePlayerStatsInitialized();

          await _trimAllGroupsHistory();
        },
      );

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

  Future<void> _createAuxiliaryTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS player_stats (
        group_id INTEGER NOT NULL,
        scope TEXT NOT NULL,
        player_name TEXT NOT NULL,
        games_played INTEGER NOT NULL DEFAULT 0,
        civil_wins INTEGER NOT NULL DEFAULT 0,
        impostor_wins INTEGER NOT NULL DEFAULT 0,
        total_points INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (group_id, scope, player_name)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAuxiliaryIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_games_group_played_at ON games (group_id, played_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_games_group_category_played_at ON games (group_id, category, played_at DESC, id DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_player_stats_lookup ON player_stats (group_id, scope, total_points DESC, player_name COLLATE NOCASE)',
    );
  }

  Future<void> _ensurePlayerStatsInitialized() async {
    if (await _isMetaFlagEnabled(_playerStatsInitializedKey)) {
      return;
    }

    if (await _isPlayerStatsTableEmpty()) {
      await _rebuildPlayerStatsFromHistory();
    }

    await _setMetaValue(_playerStatsInitializedKey, '1');
  }

  Future<bool> _isPlayerStatsTableEmpty() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS count FROM player_stats',
    ).getSingle();
    return _readInt(result, 'count') == 0;
  }

  Future<bool> _isMetaFlagEnabled(String key) async {
    final row = await customSelect(
      'SELECT value FROM app_meta WHERE key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();

    return row?.read<String>('value') == '1';
  }

  Future<void> _setMetaValue(String key, String value) {
    return customStatement(
      '''
      INSERT INTO app_meta (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      [key, value],
    );
  }

  Future<void> _rebuildPlayerStatsFromHistory() async {
    await customStatement('DELETE FROM player_stats');

    await customStatement('''
      INSERT INTO player_stats (
        group_id,
        scope,
        player_name,
        games_played,
        civil_wins,
        impostor_wins,
        total_points
      )
      SELECT
        g.group_id,
        '$_overallStatsScope',
        gp.player_name,
        COUNT(DISTINCT gp.game_id),
        COALESCE(SUM(CASE WHEN gp.was_impostor = 0 AND g.civils_won = 1 THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN gp.was_impostor = 1 AND g.civils_won = 0 THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(gp.points), 0)
      FROM ${gamePlayersTable.actualTableName} gp
      INNER JOIN games g ON gp.game_id = g.id
      WHERE g.group_id IS NOT NULL
      GROUP BY g.group_id, gp.player_name
    ''');

    await customStatement('''
      INSERT INTO player_stats (
        group_id,
        scope,
        player_name,
        games_played,
        civil_wins,
        impostor_wins,
        total_points
      )
      SELECT
        g.group_id,
        g.category,
        gp.player_name,
        COUNT(DISTINCT gp.game_id),
        COALESCE(SUM(CASE WHEN gp.was_impostor = 0 AND g.civils_won = 1 THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN gp.was_impostor = 1 AND g.civils_won = 0 THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(gp.points), 0)
      FROM ${gamePlayersTable.actualTableName} gp
      INNER JOIN games g ON gp.game_id = g.id
      WHERE g.group_id IS NOT NULL
      GROUP BY g.group_id, g.category, gp.player_name
    ''');
  }

  Future<void> _trimAllGroupsHistory() async {
    final rows = await customSelect(
      'SELECT DISTINCT group_id FROM games WHERE group_id IS NOT NULL',
      readsFrom: {games},
    ).get();

    final gameDao = GameDao(this);
    for (final row in rows) {
      await gameDao.trimGameHistory(_readInt(row, 'group_id'));
    }
  }

  int _readInt(QueryRow row, String columnName) {
    return row.read<int>(columnName);
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
    final gameIds = await db.customSelect(
      'SELECT id FROM games WHERE group_id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {db.games},
    ).get();

    for (final row in gameIds) {
      final gameId = row.read<int>('id');
      await db.customStatement(
        'DELETE FROM ${db.gamePlayersTable.actualTableName} WHERE game_id = ?',
        [gameId],
      );
    }

    await db.customStatement(
      'DELETE FROM games WHERE group_id = ?',
      [id],
    );
    await db.customStatement(
      'DELETE FROM player_stats WHERE group_id = ?',
      [id],
    );
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

      if (groupId != null) {
        await _updatePlayerStats(
          groupId: groupId,
          category: category,
          civilsWon: civilsWon,
          playerResults: playerResults,
        );
        await trimGameHistory(groupId);
      }

      return gameId;
    });
  }

  /// Get all games for a given group ordered by most recent first.
  Future<List<Game>> getGamesForGroup(int groupId) {
    return (select(games)
          ..where((g) => g.groupId.equals(groupId))
          ..orderBy([(g) => OrderingTerm.desc(g.playedAt), (g) => OrderingTerm.desc(g.id)])
          ..limit(20))
        .get();
  }

  /// Get games for a group filtered by [category].
  Future<List<Game>> getGamesForGroupByCategory(
      int groupId, String category) {
    return (select(games)
          ..where(
              (g) => g.groupId.equals(groupId) & g.category.equals(category))
          ..orderBy([(g) => OrderingTerm.desc(g.playedAt), (g) => OrderingTerm.desc(g.id)])
          ..limit(20))
        .get();
  }

  /// Aggregate ranking for a group: total points per player, sorted
  /// descending.
  Future<List<PlayerRanking>> getRankingForGroup(int groupId) async {
    final query = customSelect(
      'SELECT '
      'player_name AS name, '
      'games_played, '
      'civil_wins, '
      'impostor_wins, '
      'total_points '
      'FROM player_stats '
      'WHERE group_id = ? AND scope = ? '
      'ORDER BY total_points DESC, civil_wins DESC, impostor_wins DESC, player_name COLLATE NOCASE ASC',
      variables: [
        Variable.withInt(groupId),
        Variable.withString(_overallStatsScope),
      ],
    );

    final rows = await query.get();
    return rows
        .map((row) => PlayerRanking(
              playerName: row.read<String>('name'),
              gamesPlayed: _readInt(row, 'games_played'),
              civilWins: _readInt(row, 'civil_wins'),
              impostorWins: _readInt(row, 'impostor_wins'),
              totalPoints: _readInt(row, 'total_points'),
            ))
        .toList();
  }

  /// Aggregate ranking for a group filtered by [category].
  Future<List<PlayerRanking>> getRankingForGroupByCategory(
      int groupId, String category) async {
    final query = customSelect(
      'SELECT '
      'player_name AS name, '
      'games_played, '
      'civil_wins, '
      'impostor_wins, '
      'total_points '
      'FROM player_stats '
      'WHERE group_id = ? AND scope = ? '
      'ORDER BY total_points DESC, civil_wins DESC, impostor_wins DESC, player_name COLLATE NOCASE ASC',
      variables: [Variable.withInt(groupId), Variable.withString(category)],
    );

    final rows = await query.get();
    return rows
        .map((row) => PlayerRanking(
              playerName: row.read<String>('name'),
              gamesPlayed: _readInt(row, 'games_played'),
              civilWins: _readInt(row, 'civil_wins'),
              impostorWins: _readInt(row, 'impostor_wins'),
              totalPoints: _readInt(row, 'total_points'),
            ))
        .toList();
  }

  Future<void> _updatePlayerStats({
    required int groupId,
    required String category,
    required bool civilsWon,
    required List<GamePlayerEntry> playerResults,
  }) async {
    for (final player in playerResults) {
      final civilWins =
          !player.wasImpostor && civilsWon ? 1 : 0;
      final impostorWins =
          player.wasImpostor && !civilsWon ? 1 : 0;

      await _upsertPlayerStatsRow(
        groupId: groupId,
        scope: _overallStatsScope,
        playerName: player.playerName,
        points: player.points,
        civilWins: civilWins,
        impostorWins: impostorWins,
      );

      await _upsertPlayerStatsRow(
        groupId: groupId,
        scope: category,
        playerName: player.playerName,
        points: player.points,
        civilWins: civilWins,
        impostorWins: impostorWins,
      );
    }
  }

  Future<void> _upsertPlayerStatsRow({
    required int groupId,
    required String scope,
    required String playerName,
    required int points,
    required int civilWins,
    required int impostorWins,
  }) {
    return customStatement(
      '''
      INSERT INTO player_stats (
        group_id,
        scope,
        player_name,
        games_played,
        civil_wins,
        impostor_wins,
        total_points
      ) VALUES (?, ?, ?, 1, ?, ?, ?)
      ON CONFLICT(group_id, scope, player_name) DO UPDATE SET
        games_played = games_played + 1,
        civil_wins = civil_wins + excluded.civil_wins,
        impostor_wins = impostor_wins + excluded.impostor_wins,
        total_points = total_points + excluded.total_points
      ''',
      [
        groupId,
        scope,
        playerName,
        civilWins,
        impostorWins,
        points,
      ],
    );
  }

  /// Replace an existing game's result: reverse old stats, delete old records,
  /// then save the corrected result.
  Future<int> replaceGameResult({
    required int oldGameId,
    required int? groupId,
    required String category,
    required String word,
    required int duration,
    required int impostorCount,
    required bool hintsEnabled,
    required bool newCivilsWon,
    required bool newImpostorGuessedWord,
    required bool oldCivilsWon,
    required List<GamePlayerEntry> oldPlayerResults,
    required List<GamePlayerEntry> newPlayerResults,
  }) async {
    return transaction(() async {
      // Reverse old stats if group game
      if (groupId != null) {
        for (final player in oldPlayerResults) {
          final oldCivilWin =
              !player.wasImpostor && oldCivilsWon ? 1 : 0;
          final oldImpostorWin =
              player.wasImpostor && !oldCivilsWon ? 1 : 0;

          for (final scope in [_overallStatsScope, category]) {
            await _reversePlayerStats(
              groupId: groupId,
              scope: scope,
              playerName: player.playerName,
              points: player.points,
              civilWins: oldCivilWin,
              impostorWins: oldImpostorWin,
            );
          }
        }
      }

      // Delete old game records
      await (delete(gamePlayersTable)
            ..where((p) => p.gameId.equals(oldGameId)))
          .go();
      await (delete(games)..where((g) => g.id.equals(oldGameId))).go();

      // Save new result (this also updates stats with new values)
      return saveGame(
        groupId: groupId,
        category: category,
        word: word,
        duration: duration,
        impostorCount: impostorCount,
        hintsEnabled: hintsEnabled,
        civilsWon: newCivilsWon,
        impostorGuessedWord: newImpostorGuessedWord,
        playerResults: newPlayerResults,
      );
    });
  }

  Future<void> _reversePlayerStats({
    required int groupId,
    required String scope,
    required String playerName,
    required int points,
    required int civilWins,
    required int impostorWins,
  }) {
    return customStatement(
      '''
      UPDATE player_stats SET
        games_played = MAX(0, games_played - 1),
        civil_wins = MAX(0, civil_wins - ?),
        impostor_wins = MAX(0, impostor_wins - ?),
        total_points = MAX(0, total_points - ?)
      WHERE group_id = ? AND scope = ? AND player_name = ?
      ''',
      [
        civilWins,
        impostorWins,
        points,
        groupId,
        scope,
        playerName,
      ],
    );
  }

  Future<void> trimGameHistory(int groupId) async {
    final rows = await customSelect(
      '''
      SELECT id
      FROM games
      WHERE group_id = ?
      ORDER BY played_at DESC, id DESC
      LIMIT -1 OFFSET 20
      ''',
      variables: [Variable.withInt(groupId)],
      readsFrom: {games},
    ).get();

    if (rows.isEmpty) return;

    final gameIds = rows.map((row) => _readInt(row, 'id')).toList();

    for (final gameId in gameIds) {
      await customStatement(
        'DELETE FROM ${gamePlayersTable.actualTableName} WHERE game_id = ?',
        [gameId],
      );
      await customStatement(
        'DELETE FROM games WHERE id = ?',
        [gameId],
      );
    }
  }

  Future<void> clearHistoryForGroup(int groupId) async {
    final rows = await customSelect(
      'SELECT id FROM games WHERE group_id = ?',
      variables: [Variable.withInt(groupId)],
      readsFrom: {games},
    ).get();

    for (final row in rows) {
      final gameId = _readInt(row, 'id');
      await customStatement(
        'DELETE FROM ${gamePlayersTable.actualTableName} WHERE game_id = ?',
        [gameId],
      );
    }

    await customStatement(
      'DELETE FROM games WHERE group_id = ?',
      [groupId],
    );
  }

  Future<void> clearRankingForGroup(int groupId) {
    return customStatement(
      'DELETE FROM player_stats WHERE group_id = ?',
      [groupId],
    );
  }

  int _readInt(QueryRow row, String columnName) {
    return row.read<int>(columnName);
  }

  /// Batch-load details for multiple games in a single query.
  Future<List<GameDetails>> getGamesWithPlayers(List<Game> gamesList) async {
    if (gamesList.isEmpty) return [];

    final gameIds = gamesList.map((g) => g.id).toList();
    final allPlayers = await (select(gamePlayersTable)
          ..where((p) => p.gameId.isIn(gameIds)))
        .get();

    final playersByGameId = <int, List<GamePlayersTableData>>{};
    for (final player in allPlayers) {
      playersByGameId.putIfAbsent(player.gameId, () => []).add(player);
    }

    return gamesList
        .map((game) => GameDetails(
              game: game,
              players: playersByGameId[game.id] ?? [],
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
  final int gamesPlayed;
  final int civilWins;
  final int impostorWins;
  final int totalPoints;

  const PlayerRanking({
    required this.playerName,
    required this.gamesPlayed,
    required this.civilWins,
    required this.impostorWins,
    required this.totalPoints,
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
