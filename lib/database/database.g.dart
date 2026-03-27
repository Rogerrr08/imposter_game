// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final int id;
  final String name;
  final DateTime createdAt;
  const Group({required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Group copyWith({int? id, String? name, DateTime? createdAt}) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Group> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GroupPlayersTable extends GroupPlayers
    with TableInfo<$GroupPlayersTable, GroupPlayer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupPlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, groupId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_players';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupPlayer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupPlayer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupPlayer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $GroupPlayersTable createAlias(String alias) {
    return $GroupPlayersTable(attachedDatabase, alias);
  }
}

class GroupPlayer extends DataClass implements Insertable<GroupPlayer> {
  final int id;
  final int groupId;
  final String name;
  const GroupPlayer({
    required this.id,
    required this.groupId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<int>(groupId);
    map['name'] = Variable<String>(name);
    return map;
  }

  GroupPlayersCompanion toCompanion(bool nullToAbsent) {
    return GroupPlayersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
    );
  }

  factory GroupPlayer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupPlayer(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int>(groupId),
      'name': serializer.toJson<String>(name),
    };
  }

  GroupPlayer copyWith({int? id, int? groupId, String? name}) => GroupPlayer(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
  );
  GroupPlayer copyWithCompanion(GroupPlayersCompanion data) {
    return GroupPlayer(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupPlayer(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupPlayer &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name);
}

class GroupPlayersCompanion extends UpdateCompanion<GroupPlayer> {
  final Value<int> id;
  final Value<int> groupId;
  final Value<String> name;
  const GroupPlayersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
  });
  GroupPlayersCompanion.insert({
    this.id = const Value.absent(),
    required int groupId,
    required String name,
  }) : groupId = Value(groupId),
       name = Value(name);
  static Insertable<GroupPlayer> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
    });
  }

  GroupPlayersCompanion copyWith({
    Value<int>? id,
    Value<int>? groupId,
    Value<String>? name,
  }) {
    return GroupPlayersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupPlayersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $GamesTable extends Games with TableInfo<$GamesTable, Game> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _impostorCountMeta = const VerificationMeta(
    'impostorCount',
  );
  @override
  late final GeneratedColumn<int> impostorCount = GeneratedColumn<int>(
    'impostor_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hintsEnabledMeta = const VerificationMeta(
    'hintsEnabled',
  );
  @override
  late final GeneratedColumn<bool> hintsEnabled = GeneratedColumn<bool>(
    'hints_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hints_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _civilsWonMeta = const VerificationMeta(
    'civilsWon',
  );
  @override
  late final GeneratedColumn<bool> civilsWon = GeneratedColumn<bool>(
    'civils_won',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("civils_won" IN (0, 1))',
    ),
  );
  static const VerificationMeta _impostorGuessedWordMeta =
      const VerificationMeta('impostorGuessedWord');
  @override
  late final GeneratedColumn<bool> impostorGuessedWord = GeneratedColumn<bool>(
    'impostor_guessed_word',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("impostor_guessed_word" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    category,
    word,
    duration,
    impostorCount,
    hintsEnabled,
    civilsWon,
    impostorGuessedWord,
    playedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<Game> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('impostor_count')) {
      context.handle(
        _impostorCountMeta,
        impostorCount.isAcceptableOrUnknown(
          data['impostor_count']!,
          _impostorCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_impostorCountMeta);
    }
    if (data.containsKey('hints_enabled')) {
      context.handle(
        _hintsEnabledMeta,
        hintsEnabled.isAcceptableOrUnknown(
          data['hints_enabled']!,
          _hintsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('civils_won')) {
      context.handle(
        _civilsWonMeta,
        civilsWon.isAcceptableOrUnknown(data['civils_won']!, _civilsWonMeta),
      );
    } else if (isInserting) {
      context.missing(_civilsWonMeta);
    }
    if (data.containsKey('impostor_guessed_word')) {
      context.handle(
        _impostorGuessedWordMeta,
        impostorGuessedWord.isAcceptableOrUnknown(
          data['impostor_guessed_word']!,
          _impostorGuessedWordMeta,
        ),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Game map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Game(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      impostorCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}impostor_count'],
      )!,
      hintsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hints_enabled'],
      )!,
      civilsWon: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}civils_won'],
      )!,
      impostorGuessedWord: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}impostor_guessed_word'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class Game extends DataClass implements Insertable<Game> {
  final int id;
  final int? groupId;
  final String category;
  final String word;
  final int duration;
  final int impostorCount;
  final bool hintsEnabled;
  final bool civilsWon;
  final bool impostorGuessedWord;
  final DateTime playedAt;
  const Game({
    required this.id,
    this.groupId,
    required this.category,
    required this.word,
    required this.duration,
    required this.impostorCount,
    required this.hintsEnabled,
    required this.civilsWon,
    required this.impostorGuessedWord,
    required this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    map['category'] = Variable<String>(category);
    map['word'] = Variable<String>(word);
    map['duration'] = Variable<int>(duration);
    map['impostor_count'] = Variable<int>(impostorCount);
    map['hints_enabled'] = Variable<bool>(hintsEnabled);
    map['civils_won'] = Variable<bool>(civilsWon);
    map['impostor_guessed_word'] = Variable<bool>(impostorGuessedWord);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      category: Value(category),
      word: Value(word),
      duration: Value(duration),
      impostorCount: Value(impostorCount),
      hintsEnabled: Value(hintsEnabled),
      civilsWon: Value(civilsWon),
      impostorGuessedWord: Value(impostorGuessedWord),
      playedAt: Value(playedAt),
    );
  }

  factory Game.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Game(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      category: serializer.fromJson<String>(json['category']),
      word: serializer.fromJson<String>(json['word']),
      duration: serializer.fromJson<int>(json['duration']),
      impostorCount: serializer.fromJson<int>(json['impostorCount']),
      hintsEnabled: serializer.fromJson<bool>(json['hintsEnabled']),
      civilsWon: serializer.fromJson<bool>(json['civilsWon']),
      impostorGuessedWord: serializer.fromJson<bool>(
        json['impostorGuessedWord'],
      ),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<int?>(groupId),
      'category': serializer.toJson<String>(category),
      'word': serializer.toJson<String>(word),
      'duration': serializer.toJson<int>(duration),
      'impostorCount': serializer.toJson<int>(impostorCount),
      'hintsEnabled': serializer.toJson<bool>(hintsEnabled),
      'civilsWon': serializer.toJson<bool>(civilsWon),
      'impostorGuessedWord': serializer.toJson<bool>(impostorGuessedWord),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  Game copyWith({
    int? id,
    Value<int?> groupId = const Value.absent(),
    String? category,
    String? word,
    int? duration,
    int? impostorCount,
    bool? hintsEnabled,
    bool? civilsWon,
    bool? impostorGuessedWord,
    DateTime? playedAt,
  }) => Game(
    id: id ?? this.id,
    groupId: groupId.present ? groupId.value : this.groupId,
    category: category ?? this.category,
    word: word ?? this.word,
    duration: duration ?? this.duration,
    impostorCount: impostorCount ?? this.impostorCount,
    hintsEnabled: hintsEnabled ?? this.hintsEnabled,
    civilsWon: civilsWon ?? this.civilsWon,
    impostorGuessedWord: impostorGuessedWord ?? this.impostorGuessedWord,
    playedAt: playedAt ?? this.playedAt,
  );
  Game copyWithCompanion(GamesCompanion data) {
    return Game(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      category: data.category.present ? data.category.value : this.category,
      word: data.word.present ? data.word.value : this.word,
      duration: data.duration.present ? data.duration.value : this.duration,
      impostorCount: data.impostorCount.present
          ? data.impostorCount.value
          : this.impostorCount,
      hintsEnabled: data.hintsEnabled.present
          ? data.hintsEnabled.value
          : this.hintsEnabled,
      civilsWon: data.civilsWon.present ? data.civilsWon.value : this.civilsWon,
      impostorGuessedWord: data.impostorGuessedWord.present
          ? data.impostorGuessedWord.value
          : this.impostorGuessedWord,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Game(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category, ')
          ..write('word: $word, ')
          ..write('duration: $duration, ')
          ..write('impostorCount: $impostorCount, ')
          ..write('hintsEnabled: $hintsEnabled, ')
          ..write('civilsWon: $civilsWon, ')
          ..write('impostorGuessedWord: $impostorGuessedWord, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    category,
    word,
    duration,
    impostorCount,
    hintsEnabled,
    civilsWon,
    impostorGuessedWord,
    playedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Game &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.category == this.category &&
          other.word == this.word &&
          other.duration == this.duration &&
          other.impostorCount == this.impostorCount &&
          other.hintsEnabled == this.hintsEnabled &&
          other.civilsWon == this.civilsWon &&
          other.impostorGuessedWord == this.impostorGuessedWord &&
          other.playedAt == this.playedAt);
}

class GamesCompanion extends UpdateCompanion<Game> {
  final Value<int> id;
  final Value<int?> groupId;
  final Value<String> category;
  final Value<String> word;
  final Value<int> duration;
  final Value<int> impostorCount;
  final Value<bool> hintsEnabled;
  final Value<bool> civilsWon;
  final Value<bool> impostorGuessedWord;
  final Value<DateTime> playedAt;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.category = const Value.absent(),
    this.word = const Value.absent(),
    this.duration = const Value.absent(),
    this.impostorCount = const Value.absent(),
    this.hintsEnabled = const Value.absent(),
    this.civilsWon = const Value.absent(),
    this.impostorGuessedWord = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    required String category,
    required String word,
    required int duration,
    required int impostorCount,
    this.hintsEnabled = const Value.absent(),
    required bool civilsWon,
    this.impostorGuessedWord = const Value.absent(),
    this.playedAt = const Value.absent(),
  }) : category = Value(category),
       word = Value(word),
       duration = Value(duration),
       impostorCount = Value(impostorCount),
       civilsWon = Value(civilsWon);
  static Insertable<Game> custom({
    Expression<int>? id,
    Expression<int>? groupId,
    Expression<String>? category,
    Expression<String>? word,
    Expression<int>? duration,
    Expression<int>? impostorCount,
    Expression<bool>? hintsEnabled,
    Expression<bool>? civilsWon,
    Expression<bool>? impostorGuessedWord,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (category != null) 'category': category,
      if (word != null) 'word': word,
      if (duration != null) 'duration': duration,
      if (impostorCount != null) 'impostor_count': impostorCount,
      if (hintsEnabled != null) 'hints_enabled': hintsEnabled,
      if (civilsWon != null) 'civils_won': civilsWon,
      if (impostorGuessedWord != null)
        'impostor_guessed_word': impostorGuessedWord,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<int?>? groupId,
    Value<String>? category,
    Value<String>? word,
    Value<int>? duration,
    Value<int>? impostorCount,
    Value<bool>? hintsEnabled,
    Value<bool>? civilsWon,
    Value<bool>? impostorGuessedWord,
    Value<DateTime>? playedAt,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      category: category ?? this.category,
      word: word ?? this.word,
      duration: duration ?? this.duration,
      impostorCount: impostorCount ?? this.impostorCount,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      civilsWon: civilsWon ?? this.civilsWon,
      impostorGuessedWord: impostorGuessedWord ?? this.impostorGuessedWord,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (impostorCount.present) {
      map['impostor_count'] = Variable<int>(impostorCount.value);
    }
    if (hintsEnabled.present) {
      map['hints_enabled'] = Variable<bool>(hintsEnabled.value);
    }
    if (civilsWon.present) {
      map['civils_won'] = Variable<bool>(civilsWon.value);
    }
    if (impostorGuessedWord.present) {
      map['impostor_guessed_word'] = Variable<bool>(impostorGuessedWord.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category, ')
          ..write('word: $word, ')
          ..write('duration: $duration, ')
          ..write('impostorCount: $impostorCount, ')
          ..write('hintsEnabled: $hintsEnabled, ')
          ..write('civilsWon: $civilsWon, ')
          ..write('impostorGuessedWord: $impostorGuessedWord, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $GamePlayersTableTable extends GamePlayersTable
    with TableInfo<$GamePlayersTableTable, GamePlayersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamePlayersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id)',
    ),
  );
  static const VerificationMeta _playerNameMeta = const VerificationMeta(
    'playerName',
  );
  @override
  late final GeneratedColumn<String> playerName = GeneratedColumn<String>(
    'player_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wasImpostorMeta = const VerificationMeta(
    'wasImpostor',
  );
  @override
  late final GeneratedColumn<bool> wasImpostor = GeneratedColumn<bool>(
    'was_impostor',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_impostor" IN (0, 1))',
    ),
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wasEliminatedMeta = const VerificationMeta(
    'wasEliminated',
  );
  @override
  late final GeneratedColumn<bool> wasEliminated = GeneratedColumn<bool>(
    'was_eliminated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_eliminated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gameId,
    playerName,
    wasImpostor,
    points,
    wasEliminated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_players_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GamePlayersTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('player_name')) {
      context.handle(
        _playerNameMeta,
        playerName.isAcceptableOrUnknown(data['player_name']!, _playerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_playerNameMeta);
    }
    if (data.containsKey('was_impostor')) {
      context.handle(
        _wasImpostorMeta,
        wasImpostor.isAcceptableOrUnknown(
          data['was_impostor']!,
          _wasImpostorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wasImpostorMeta);
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('was_eliminated')) {
      context.handle(
        _wasEliminatedMeta,
        wasEliminated.isAcceptableOrUnknown(
          data['was_eliminated']!,
          _wasEliminatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GamePlayersTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GamePlayersTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      playerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_name'],
      )!,
      wasImpostor: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_impostor'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      )!,
      wasEliminated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_eliminated'],
      )!,
    );
  }

  @override
  $GamePlayersTableTable createAlias(String alias) {
    return $GamePlayersTableTable(attachedDatabase, alias);
  }
}

class GamePlayersTableData extends DataClass
    implements Insertable<GamePlayersTableData> {
  final int id;
  final int gameId;
  final String playerName;
  final bool wasImpostor;
  final int points;
  final bool wasEliminated;
  const GamePlayersTableData({
    required this.id,
    required this.gameId,
    required this.playerName,
    required this.wasImpostor,
    required this.points,
    required this.wasEliminated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['game_id'] = Variable<int>(gameId);
    map['player_name'] = Variable<String>(playerName);
    map['was_impostor'] = Variable<bool>(wasImpostor);
    map['points'] = Variable<int>(points);
    map['was_eliminated'] = Variable<bool>(wasEliminated);
    return map;
  }

  GamePlayersTableCompanion toCompanion(bool nullToAbsent) {
    return GamePlayersTableCompanion(
      id: Value(id),
      gameId: Value(gameId),
      playerName: Value(playerName),
      wasImpostor: Value(wasImpostor),
      points: Value(points),
      wasEliminated: Value(wasEliminated),
    );
  }

  factory GamePlayersTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GamePlayersTableData(
      id: serializer.fromJson<int>(json['id']),
      gameId: serializer.fromJson<int>(json['gameId']),
      playerName: serializer.fromJson<String>(json['playerName']),
      wasImpostor: serializer.fromJson<bool>(json['wasImpostor']),
      points: serializer.fromJson<int>(json['points']),
      wasEliminated: serializer.fromJson<bool>(json['wasEliminated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'gameId': serializer.toJson<int>(gameId),
      'playerName': serializer.toJson<String>(playerName),
      'wasImpostor': serializer.toJson<bool>(wasImpostor),
      'points': serializer.toJson<int>(points),
      'wasEliminated': serializer.toJson<bool>(wasEliminated),
    };
  }

  GamePlayersTableData copyWith({
    int? id,
    int? gameId,
    String? playerName,
    bool? wasImpostor,
    int? points,
    bool? wasEliminated,
  }) => GamePlayersTableData(
    id: id ?? this.id,
    gameId: gameId ?? this.gameId,
    playerName: playerName ?? this.playerName,
    wasImpostor: wasImpostor ?? this.wasImpostor,
    points: points ?? this.points,
    wasEliminated: wasEliminated ?? this.wasEliminated,
  );
  GamePlayersTableData copyWithCompanion(GamePlayersTableCompanion data) {
    return GamePlayersTableData(
      id: data.id.present ? data.id.value : this.id,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      playerName: data.playerName.present
          ? data.playerName.value
          : this.playerName,
      wasImpostor: data.wasImpostor.present
          ? data.wasImpostor.value
          : this.wasImpostor,
      points: data.points.present ? data.points.value : this.points,
      wasEliminated: data.wasEliminated.present
          ? data.wasEliminated.value
          : this.wasEliminated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GamePlayersTableData(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('playerName: $playerName, ')
          ..write('wasImpostor: $wasImpostor, ')
          ..write('points: $points, ')
          ..write('wasEliminated: $wasEliminated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, gameId, playerName, wasImpostor, points, wasEliminated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GamePlayersTableData &&
          other.id == this.id &&
          other.gameId == this.gameId &&
          other.playerName == this.playerName &&
          other.wasImpostor == this.wasImpostor &&
          other.points == this.points &&
          other.wasEliminated == this.wasEliminated);
}

class GamePlayersTableCompanion extends UpdateCompanion<GamePlayersTableData> {
  final Value<int> id;
  final Value<int> gameId;
  final Value<String> playerName;
  final Value<bool> wasImpostor;
  final Value<int> points;
  final Value<bool> wasEliminated;
  const GamePlayersTableCompanion({
    this.id = const Value.absent(),
    this.gameId = const Value.absent(),
    this.playerName = const Value.absent(),
    this.wasImpostor = const Value.absent(),
    this.points = const Value.absent(),
    this.wasEliminated = const Value.absent(),
  });
  GamePlayersTableCompanion.insert({
    this.id = const Value.absent(),
    required int gameId,
    required String playerName,
    required bool wasImpostor,
    this.points = const Value.absent(),
    this.wasEliminated = const Value.absent(),
  }) : gameId = Value(gameId),
       playerName = Value(playerName),
       wasImpostor = Value(wasImpostor);
  static Insertable<GamePlayersTableData> custom({
    Expression<int>? id,
    Expression<int>? gameId,
    Expression<String>? playerName,
    Expression<bool>? wasImpostor,
    Expression<int>? points,
    Expression<bool>? wasEliminated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gameId != null) 'game_id': gameId,
      if (playerName != null) 'player_name': playerName,
      if (wasImpostor != null) 'was_impostor': wasImpostor,
      if (points != null) 'points': points,
      if (wasEliminated != null) 'was_eliminated': wasEliminated,
    });
  }

  GamePlayersTableCompanion copyWith({
    Value<int>? id,
    Value<int>? gameId,
    Value<String>? playerName,
    Value<bool>? wasImpostor,
    Value<int>? points,
    Value<bool>? wasEliminated,
  }) {
    return GamePlayersTableCompanion(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      playerName: playerName ?? this.playerName,
      wasImpostor: wasImpostor ?? this.wasImpostor,
      points: points ?? this.points,
      wasEliminated: wasEliminated ?? this.wasEliminated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (playerName.present) {
      map['player_name'] = Variable<String>(playerName.value);
    }
    if (wasImpostor.present) {
      map['was_impostor'] = Variable<bool>(wasImpostor.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (wasEliminated.present) {
      map['was_eliminated'] = Variable<bool>(wasEliminated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamePlayersTableCompanion(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('playerName: $playerName, ')
          ..write('wasImpostor: $wasImpostor, ')
          ..write('points: $points, ')
          ..write('wasEliminated: $wasEliminated')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $GroupPlayersTable groupPlayers = $GroupPlayersTable(this);
  late final $GamesTable games = $GamesTable(this);
  late final $GamePlayersTableTable gamePlayersTable = $GamePlayersTableTable(
    this,
  );
  late final GroupDao groupDao = GroupDao(this as AppDatabase);
  late final GameDao gameDao = GameDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    groups,
    groupPlayers,
    games,
    gamePlayersTable,
  ];
}

typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<DateTime> createdAt,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$GroupsTableReferences
    extends BaseReferences<_$AppDatabase, $GroupsTable, Group> {
  $$GroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GroupPlayersTable, List<GroupPlayer>>
  _groupPlayersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.groupPlayers,
    aliasName: $_aliasNameGenerator(db.groups.id, db.groupPlayers.groupId),
  );

  $$GroupPlayersTableProcessedTableManager get groupPlayersRefs {
    final manager = $$GroupPlayersTableTableManager(
      $_db,
      $_db.groupPlayers,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupPlayersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GamesTable, List<Game>> _gamesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.games,
    aliasName: $_aliasNameGenerator(db.groups.id, db.games.groupId),
  );

  $$GamesTableProcessedTableManager get gamesRefs {
    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gamesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> groupPlayersRefs(
    Expression<bool> Function($$GroupPlayersTableFilterComposer f) f,
  ) {
    final $$GroupPlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupPlayers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupPlayersTableFilterComposer(
            $db: $db,
            $table: $db.groupPlayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gamesRefs(
    Expression<bool> Function($$GamesTableFilterComposer f) f,
  ) {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> groupPlayersRefs<T extends Object>(
    Expression<T> Function($$GroupPlayersTableAnnotationComposer a) f,
  ) {
    final $$GroupPlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupPlayers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupPlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupPlayers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gamesRefs<T extends Object>(
    Expression<T> Function($$GamesTableAnnotationComposer a) f,
  ) {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, $$GroupsTableReferences),
          Group,
          PrefetchHooks Function({bool groupPlayersRefs, bool gamesRefs})
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GroupsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GroupsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({groupPlayersRefs = false, gamesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (groupPlayersRefs) db.groupPlayers,
                    if (gamesRefs) db.games,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (groupPlayersRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          GroupPlayer
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._groupPlayersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).groupPlayersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (gamesRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Game>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._gamesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(db, table, p0).gamesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, $$GroupsTableReferences),
      Group,
      PrefetchHooks Function({bool groupPlayersRefs, bool gamesRefs})
    >;
typedef $$GroupPlayersTableCreateCompanionBuilder =
    GroupPlayersCompanion Function({
      Value<int> id,
      required int groupId,
      required String name,
    });
typedef $$GroupPlayersTableUpdateCompanionBuilder =
    GroupPlayersCompanion Function({
      Value<int> id,
      Value<int> groupId,
      Value<String> name,
    });

final class $$GroupPlayersTableReferences
    extends BaseReferences<_$AppDatabase, $GroupPlayersTable, GroupPlayer> {
  $$GroupPlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.groupPlayers.groupId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupPlayersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupPlayersTable> {
  $$GroupPlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupPlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupPlayersTable> {
  $$GroupPlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupPlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupPlayersTable> {
  $$GroupPlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupPlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupPlayersTable,
          GroupPlayer,
          $$GroupPlayersTableFilterComposer,
          $$GroupPlayersTableOrderingComposer,
          $$GroupPlayersTableAnnotationComposer,
          $$GroupPlayersTableCreateCompanionBuilder,
          $$GroupPlayersTableUpdateCompanionBuilder,
          (GroupPlayer, $$GroupPlayersTableReferences),
          GroupPlayer,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupPlayersTableTableManager(_$AppDatabase db, $GroupPlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupPlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupPlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupPlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => GroupPlayersCompanion(id: id, groupId: groupId, name: name),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int groupId,
                required String name,
              }) => GroupPlayersCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GroupPlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$GroupPlayersTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$GroupPlayersTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupPlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupPlayersTable,
      GroupPlayer,
      $$GroupPlayersTableFilterComposer,
      $$GroupPlayersTableOrderingComposer,
      $$GroupPlayersTableAnnotationComposer,
      $$GroupPlayersTableCreateCompanionBuilder,
      $$GroupPlayersTableUpdateCompanionBuilder,
      (GroupPlayer, $$GroupPlayersTableReferences),
      GroupPlayer,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      Value<int?> groupId,
      required String category,
      required String word,
      required int duration,
      required int impostorCount,
      Value<bool> hintsEnabled,
      required bool civilsWon,
      Value<bool> impostorGuessedWord,
      Value<DateTime> playedAt,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      Value<int?> groupId,
      Value<String> category,
      Value<String> word,
      Value<int> duration,
      Value<int> impostorCount,
      Value<bool> hintsEnabled,
      Value<bool> civilsWon,
      Value<bool> impostorGuessedWord,
      Value<DateTime> playedAt,
    });

final class $$GamesTableReferences
    extends BaseReferences<_$AppDatabase, $GamesTable, Game> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.games.groupId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$GamePlayersTableTable, List<GamePlayersTableData>>
  _gamePlayersTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gamePlayersTable,
    aliasName: $_aliasNameGenerator(db.games.id, db.gamePlayersTable.gameId),
  );

  $$GamePlayersTableTableProcessedTableManager get gamePlayersTableRefs {
    final manager = $$GamePlayersTableTableTableManager(
      $_db,
      $_db.gamePlayersTable,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _gamePlayersTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get impostorCount => $composableBuilder(
    column: $table.impostorCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hintsEnabled => $composableBuilder(
    column: $table.hintsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get civilsWon => $composableBuilder(
    column: $table.civilsWon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get impostorGuessedWord => $composableBuilder(
    column: $table.impostorGuessedWord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> gamePlayersTableRefs(
    Expression<bool> Function($$GamePlayersTableTableFilterComposer f) f,
  ) {
    final $$GamePlayersTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gamePlayersTable,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamePlayersTableTableFilterComposer(
            $db: $db,
            $table: $db.gamePlayersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get impostorCount => $composableBuilder(
    column: $table.impostorCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hintsEnabled => $composableBuilder(
    column: $table.hintsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get civilsWon => $composableBuilder(
    column: $table.civilsWon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get impostorGuessedWord => $composableBuilder(
    column: $table.impostorGuessedWord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get impostorCount => $composableBuilder(
    column: $table.impostorCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hintsEnabled => $composableBuilder(
    column: $table.hintsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get civilsWon =>
      $composableBuilder(column: $table.civilsWon, builder: (column) => column);

  GeneratedColumn<bool> get impostorGuessedWord => $composableBuilder(
    column: $table.impostorGuessedWord,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> gamePlayersTableRefs<T extends Object>(
    Expression<T> Function($$GamePlayersTableTableAnnotationComposer a) f,
  ) {
    final $$GamePlayersTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gamePlayersTable,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamePlayersTableTableAnnotationComposer(
            $db: $db,
            $table: $db.gamePlayersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          Game,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (Game, $$GamesTableReferences),
          Game,
          PrefetchHooks Function({bool groupId, bool gamePlayersTableRefs})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<int> impostorCount = const Value.absent(),
                Value<bool> hintsEnabled = const Value.absent(),
                Value<bool> civilsWon = const Value.absent(),
                Value<bool> impostorGuessedWord = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                groupId: groupId,
                category: category,
                word: word,
                duration: duration,
                impostorCount: impostorCount,
                hintsEnabled: hintsEnabled,
                civilsWon: civilsWon,
                impostorGuessedWord: impostorGuessedWord,
                playedAt: playedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                required String category,
                required String word,
                required int duration,
                required int impostorCount,
                Value<bool> hintsEnabled = const Value.absent(),
                required bool civilsWon,
                Value<bool> impostorGuessedWord = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                groupId: groupId,
                category: category,
                word: word,
                duration: duration,
                impostorCount: impostorCount,
                hintsEnabled: hintsEnabled,
                civilsWon: civilsWon,
                impostorGuessedWord: impostorGuessedWord,
                playedAt: playedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GamesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({groupId = false, gamePlayersTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (gamePlayersTableRefs) db.gamePlayersTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$GamesTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$GamesTableReferences
                                        ._groupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (gamePlayersTableRefs)
                        await $_getPrefetchedData<
                          Game,
                          $GamesTable,
                          GamePlayersTableData
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._gamePlayersTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).gamePlayersTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      Game,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (Game, $$GamesTableReferences),
      Game,
      PrefetchHooks Function({bool groupId, bool gamePlayersTableRefs})
    >;
typedef $$GamePlayersTableTableCreateCompanionBuilder =
    GamePlayersTableCompanion Function({
      Value<int> id,
      required int gameId,
      required String playerName,
      required bool wasImpostor,
      Value<int> points,
      Value<bool> wasEliminated,
    });
typedef $$GamePlayersTableTableUpdateCompanionBuilder =
    GamePlayersTableCompanion Function({
      Value<int> id,
      Value<int> gameId,
      Value<String> playerName,
      Value<bool> wasImpostor,
      Value<int> points,
      Value<bool> wasEliminated,
    });

final class $$GamePlayersTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GamePlayersTableTable,
          GamePlayersTableData
        > {
  $$GamePlayersTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GamesTable _gameIdTable(_$AppDatabase db) => db.games.createAlias(
    $_aliasNameGenerator(db.gamePlayersTable.gameId, db.games.id),
  );

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<int>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GamePlayersTableTableFilterComposer
    extends Composer<_$AppDatabase, $GamePlayersTableTable> {
  $$GamePlayersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasImpostor => $composableBuilder(
    column: $table.wasImpostor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasEliminated => $composableBuilder(
    column: $table.wasEliminated,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamePlayersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $GamePlayersTableTable> {
  $$GamePlayersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasImpostor => $composableBuilder(
    column: $table.wasImpostor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasEliminated => $composableBuilder(
    column: $table.wasEliminated,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamePlayersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamePlayersTableTable> {
  $$GamePlayersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playerName => $composableBuilder(
    column: $table.playerName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wasImpostor => $composableBuilder(
    column: $table.wasImpostor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<bool> get wasEliminated => $composableBuilder(
    column: $table.wasEliminated,
    builder: (column) => column,
  );

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GamePlayersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamePlayersTableTable,
          GamePlayersTableData,
          $$GamePlayersTableTableFilterComposer,
          $$GamePlayersTableTableOrderingComposer,
          $$GamePlayersTableTableAnnotationComposer,
          $$GamePlayersTableTableCreateCompanionBuilder,
          $$GamePlayersTableTableUpdateCompanionBuilder,
          (GamePlayersTableData, $$GamePlayersTableTableReferences),
          GamePlayersTableData,
          PrefetchHooks Function({bool gameId})
        > {
  $$GamePlayersTableTableTableManager(
    _$AppDatabase db,
    $GamePlayersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamePlayersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamePlayersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamePlayersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> gameId = const Value.absent(),
                Value<String> playerName = const Value.absent(),
                Value<bool> wasImpostor = const Value.absent(),
                Value<int> points = const Value.absent(),
                Value<bool> wasEliminated = const Value.absent(),
              }) => GamePlayersTableCompanion(
                id: id,
                gameId: gameId,
                playerName: playerName,
                wasImpostor: wasImpostor,
                points: points,
                wasEliminated: wasEliminated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int gameId,
                required String playerName,
                required bool wasImpostor,
                Value<int> points = const Value.absent(),
                Value<bool> wasEliminated = const Value.absent(),
              }) => GamePlayersTableCompanion.insert(
                id: id,
                gameId: gameId,
                playerName: playerName,
                wasImpostor: wasImpostor,
                points: points,
                wasEliminated: wasEliminated,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GamePlayersTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable:
                                    $$GamePlayersTableTableReferences
                                        ._gameIdTable(db),
                                referencedColumn:
                                    $$GamePlayersTableTableReferences
                                        ._gameIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GamePlayersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamePlayersTableTable,
      GamePlayersTableData,
      $$GamePlayersTableTableFilterComposer,
      $$GamePlayersTableTableOrderingComposer,
      $$GamePlayersTableTableAnnotationComposer,
      $$GamePlayersTableTableCreateCompanionBuilder,
      $$GamePlayersTableTableUpdateCompanionBuilder,
      (GamePlayersTableData, $$GamePlayersTableTableReferences),
      GamePlayersTableData,
      PrefetchHooks Function({bool gameId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$GroupPlayersTableTableManager get groupPlayers =>
      $$GroupPlayersTableTableManager(_db, _db.groupPlayers);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$GamePlayersTableTableTableManager get gamePlayersTable =>
      $$GamePlayersTableTableTableManager(_db, _db.gamePlayersTable);
}

mixin _$GroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $GroupPlayersTable get groupPlayers => attachedDatabase.groupPlayers;
  GroupDaoManager get managers => GroupDaoManager(this);
}

class GroupDaoManager {
  final _$GroupDaoMixin _db;
  GroupDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$GroupPlayersTableTableManager get groupPlayers =>
      $$GroupPlayersTableTableManager(_db.attachedDatabase, _db.groupPlayers);
}

mixin _$GameDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $GamesTable get games => attachedDatabase.games;
  $GamePlayersTableTable get gamePlayersTable =>
      attachedDatabase.gamePlayersTable;
  GameDaoManager get managers => GameDaoManager(this);
}

class GameDaoManager {
  final _$GameDaoMixin _db;
  GameDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db.attachedDatabase, _db.games);
  $$GamePlayersTableTableTableManager get gamePlayersTable =>
      $$GamePlayersTableTableTableManager(
        _db.attachedDatabase,
        _db.gamePlayersTable,
      );
}
