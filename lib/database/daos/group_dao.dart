// GroupDao is defined inside database.dart using @DriftAccessor.
//
// This file re-exports it so that consumers can import from
// 'package:imposter_game/database/daos/group_dao.dart' if they prefer a
// granular import style.

export '../database.dart' show GroupDao;
