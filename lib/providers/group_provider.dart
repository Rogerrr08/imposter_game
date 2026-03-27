import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'database_provider.dart';

// Provider for all groups
final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<Group>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() async {
    final db = ref.read(databaseProvider);
    return (db.select(
      db.groups,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<int> createGroup(String name) async {
    final db = ref.read(databaseProvider);
    final id = await db
        .into(db.groups)
        .insert(GroupsCompanion.insert(name: name));
    ref.invalidateSelf();
    return id;
  }

  Future<void> deleteGroup(int id) async {
    final db = ref.read(databaseProvider);
    await GroupDao(db).deleteGroup(id);
    ref.invalidateSelf();
    ref.invalidate(groupDetailProvider(id));
    ref.invalidate(groupPlayersProvider(id));
    ref.invalidate(groupPlayerCountProvider(id));
  }

  Future<void> updateGroupName(int id, String newName) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.groups)..where((t) => t.id.equals(id))).write(
      GroupsCompanion(name: Value(newName)),
    );
    ref.invalidateSelf();
    ref.invalidate(groupDetailProvider(id));
  }
}

// Provider for a single group
final groupDetailProvider = FutureProvider.family<Group?, int>((
  ref,
  groupId,
) async {
  final db = ref.read(databaseProvider);
  return (db.select(
    db.groups,
  )..where((t) => t.id.equals(groupId))).getSingleOrNull();
});

// Provider for players in a group (read-only)
final groupPlayersProvider = FutureProvider.family<List<GroupPlayer>, int>((
  ref,
  groupId,
) async {
  final db = ref.read(databaseProvider);
  return (db.select(db.groupPlayers)
        ..where((t) => t.groupId.equals(groupId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
});

// Service for group player mutations
class GroupPlayersService {
  final AppDatabase _db;
  GroupPlayersService(this._db);

  Future<void> addPlayer(int groupId, String name) async {
    await _db
        .into(_db.groupPlayers)
        .insert(GroupPlayersCompanion.insert(groupId: groupId, name: name));
  }

  Future<void> removePlayer(int playerId) async {
    await (_db.delete(
      _db.groupPlayers,
    )..where((t) => t.id.equals(playerId))).go();
  }

  Future<void> updatePlayerName(int playerId, String newName) async {
    await (_db.update(_db.groupPlayers)..where((t) => t.id.equals(playerId)))
        .write(GroupPlayersCompanion(name: Value(newName)));
  }
}

// Provider for player count in a group
final groupPlayerCountProvider = FutureProvider.family<int, int>((
  ref,
  groupId,
) async {
  final players = await ref.watch(groupPlayersProvider(groupId).future);
  return players.length;
});
