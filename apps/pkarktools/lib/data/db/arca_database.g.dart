// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arca_database.dart';

// ignore_for_file: type=lint
class $SaveSlotsTable extends SaveSlots
    with TableInfo<$SaveSlotsTable, SaveSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaveSlotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _identityKeyMeta = const VerificationMeta(
    'identityKey',
  );
  @override
  late final GeneratedColumn<String> identityKey = GeneratedColumn<String>(
    'identity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _gameCodeMeta = const VerificationMeta(
    'gameCode',
  );
  @override
  late final GeneratedColumn<String> gameCode = GeneratedColumn<String>(
    'game_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<int> versionId = GeneratedColumn<int>(
    'version_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trainerNameMeta = const VerificationMeta(
    'trainerName',
  );
  @override
  late final GeneratedColumn<String> trainerName = GeneratedColumn<String>(
    'trainer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tidMeta = const VerificationMeta('tid');
  @override
  late final GeneratedColumn<int> tid = GeneratedColumn<int>(
    'tid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sidMeta = const VerificationMeta('sid');
  @override
  late final GeneratedColumn<int> sid = GeneratedColumn<int>(
    'sid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayTidMeta = const VerificationMeta(
    'displayTid',
  );
  @override
  late final GeneratedColumn<String> displayTid = GeneratedColumn<String>(
    'display_tid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displaySidMeta = const VerificationMeta(
    'displaySid',
  );
  @override
  late final GeneratedColumn<String> displaySid = GeneratedColumn<String>(
    'display_sid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    identityKey,
    gameCode,
    generation,
    versionId,
    trainerName,
    tid,
    sid,
    displayTid,
    displaySid,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'save_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SaveSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('identity_key')) {
      context.handle(
        _identityKeyMeta,
        identityKey.isAcceptableOrUnknown(
          data['identity_key']!,
          _identityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('game_code')) {
      context.handle(
        _gameCodeMeta,
        gameCode.isAcceptableOrUnknown(data['game_code']!, _gameCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_gameCodeMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    }
    if (data.containsKey('trainer_name')) {
      context.handle(
        _trainerNameMeta,
        trainerName.isAcceptableOrUnknown(
          data['trainer_name']!,
          _trainerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trainerNameMeta);
    }
    if (data.containsKey('tid')) {
      context.handle(
        _tidMeta,
        tid.isAcceptableOrUnknown(data['tid']!, _tidMeta),
      );
    } else if (isInserting) {
      context.missing(_tidMeta);
    }
    if (data.containsKey('sid')) {
      context.handle(
        _sidMeta,
        sid.isAcceptableOrUnknown(data['sid']!, _sidMeta),
      );
    }
    if (data.containsKey('display_tid')) {
      context.handle(
        _displayTidMeta,
        displayTid.isAcceptableOrUnknown(data['display_tid']!, _displayTidMeta),
      );
    } else if (isInserting) {
      context.missing(_displayTidMeta);
    }
    if (data.containsKey('display_sid')) {
      context.handle(
        _displaySidMeta,
        displaySid.isAcceptableOrUnknown(data['display_sid']!, _displaySidMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaveSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaveSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      identityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_key'],
      )!,
      gameCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_code'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_id'],
      ),
      trainerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trainer_name'],
      )!,
      tid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tid'],
      )!,
      sid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sid'],
      ),
      displayTid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_tid'],
      )!,
      displaySid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_sid'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SaveSlotsTable createAlias(String alias) {
    return $SaveSlotsTable(attachedDatabase, alias);
  }
}

class SaveSlot extends DataClass implements Insertable<SaveSlot> {
  final int id;
  final String identityKey;
  final String gameCode;
  final int generation;
  final int? versionId;
  final String trainerName;
  final int tid;
  final int? sid;
  final String displayTid;
  final String? displaySid;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SaveSlot({
    required this.id,
    required this.identityKey,
    required this.gameCode,
    required this.generation,
    this.versionId,
    required this.trainerName,
    required this.tid,
    this.sid,
    required this.displayTid,
    this.displaySid,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['identity_key'] = Variable<String>(identityKey);
    map['game_code'] = Variable<String>(gameCode);
    map['generation'] = Variable<int>(generation);
    if (!nullToAbsent || versionId != null) {
      map['version_id'] = Variable<int>(versionId);
    }
    map['trainer_name'] = Variable<String>(trainerName);
    map['tid'] = Variable<int>(tid);
    if (!nullToAbsent || sid != null) {
      map['sid'] = Variable<int>(sid);
    }
    map['display_tid'] = Variable<String>(displayTid);
    if (!nullToAbsent || displaySid != null) {
      map['display_sid'] = Variable<String>(displaySid);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SaveSlotsCompanion toCompanion(bool nullToAbsent) {
    return SaveSlotsCompanion(
      id: Value(id),
      identityKey: Value(identityKey),
      gameCode: Value(gameCode),
      generation: Value(generation),
      versionId: versionId == null && nullToAbsent
          ? const Value.absent()
          : Value(versionId),
      trainerName: Value(trainerName),
      tid: Value(tid),
      sid: sid == null && nullToAbsent ? const Value.absent() : Value(sid),
      displayTid: Value(displayTid),
      displaySid: displaySid == null && nullToAbsent
          ? const Value.absent()
          : Value(displaySid),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SaveSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaveSlot(
      id: serializer.fromJson<int>(json['id']),
      identityKey: serializer.fromJson<String>(json['identityKey']),
      gameCode: serializer.fromJson<String>(json['gameCode']),
      generation: serializer.fromJson<int>(json['generation']),
      versionId: serializer.fromJson<int?>(json['versionId']),
      trainerName: serializer.fromJson<String>(json['trainerName']),
      tid: serializer.fromJson<int>(json['tid']),
      sid: serializer.fromJson<int?>(json['sid']),
      displayTid: serializer.fromJson<String>(json['displayTid']),
      displaySid: serializer.fromJson<String?>(json['displaySid']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'identityKey': serializer.toJson<String>(identityKey),
      'gameCode': serializer.toJson<String>(gameCode),
      'generation': serializer.toJson<int>(generation),
      'versionId': serializer.toJson<int?>(versionId),
      'trainerName': serializer.toJson<String>(trainerName),
      'tid': serializer.toJson<int>(tid),
      'sid': serializer.toJson<int?>(sid),
      'displayTid': serializer.toJson<String>(displayTid),
      'displaySid': serializer.toJson<String?>(displaySid),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SaveSlot copyWith({
    int? id,
    String? identityKey,
    String? gameCode,
    int? generation,
    Value<int?> versionId = const Value.absent(),
    String? trainerName,
    int? tid,
    Value<int?> sid = const Value.absent(),
    String? displayTid,
    Value<String?> displaySid = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SaveSlot(
    id: id ?? this.id,
    identityKey: identityKey ?? this.identityKey,
    gameCode: gameCode ?? this.gameCode,
    generation: generation ?? this.generation,
    versionId: versionId.present ? versionId.value : this.versionId,
    trainerName: trainerName ?? this.trainerName,
    tid: tid ?? this.tid,
    sid: sid.present ? sid.value : this.sid,
    displayTid: displayTid ?? this.displayTid,
    displaySid: displaySid.present ? displaySid.value : this.displaySid,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SaveSlot copyWithCompanion(SaveSlotsCompanion data) {
    return SaveSlot(
      id: data.id.present ? data.id.value : this.id,
      identityKey: data.identityKey.present
          ? data.identityKey.value
          : this.identityKey,
      gameCode: data.gameCode.present ? data.gameCode.value : this.gameCode,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      trainerName: data.trainerName.present
          ? data.trainerName.value
          : this.trainerName,
      tid: data.tid.present ? data.tid.value : this.tid,
      sid: data.sid.present ? data.sid.value : this.sid,
      displayTid: data.displayTid.present
          ? data.displayTid.value
          : this.displayTid,
      displaySid: data.displaySid.present
          ? data.displaySid.value
          : this.displaySid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaveSlot(')
          ..write('id: $id, ')
          ..write('identityKey: $identityKey, ')
          ..write('gameCode: $gameCode, ')
          ..write('generation: $generation, ')
          ..write('versionId: $versionId, ')
          ..write('trainerName: $trainerName, ')
          ..write('tid: $tid, ')
          ..write('sid: $sid, ')
          ..write('displayTid: $displayTid, ')
          ..write('displaySid: $displaySid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    identityKey,
    gameCode,
    generation,
    versionId,
    trainerName,
    tid,
    sid,
    displayTid,
    displaySid,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaveSlot &&
          other.id == this.id &&
          other.identityKey == this.identityKey &&
          other.gameCode == this.gameCode &&
          other.generation == this.generation &&
          other.versionId == this.versionId &&
          other.trainerName == this.trainerName &&
          other.tid == this.tid &&
          other.sid == this.sid &&
          other.displayTid == this.displayTid &&
          other.displaySid == this.displaySid &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SaveSlotsCompanion extends UpdateCompanion<SaveSlot> {
  final Value<int> id;
  final Value<String> identityKey;
  final Value<String> gameCode;
  final Value<int> generation;
  final Value<int?> versionId;
  final Value<String> trainerName;
  final Value<int> tid;
  final Value<int?> sid;
  final Value<String> displayTid;
  final Value<String?> displaySid;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SaveSlotsCompanion({
    this.id = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.gameCode = const Value.absent(),
    this.generation = const Value.absent(),
    this.versionId = const Value.absent(),
    this.trainerName = const Value.absent(),
    this.tid = const Value.absent(),
    this.sid = const Value.absent(),
    this.displayTid = const Value.absent(),
    this.displaySid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SaveSlotsCompanion.insert({
    this.id = const Value.absent(),
    required String identityKey,
    required String gameCode,
    required int generation,
    this.versionId = const Value.absent(),
    required String trainerName,
    required int tid,
    this.sid = const Value.absent(),
    required String displayTid,
    this.displaySid = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : identityKey = Value(identityKey),
       gameCode = Value(gameCode),
       generation = Value(generation),
       trainerName = Value(trainerName),
       tid = Value(tid),
       displayTid = Value(displayTid),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SaveSlot> custom({
    Expression<int>? id,
    Expression<String>? identityKey,
    Expression<String>? gameCode,
    Expression<int>? generation,
    Expression<int>? versionId,
    Expression<String>? trainerName,
    Expression<int>? tid,
    Expression<int>? sid,
    Expression<String>? displayTid,
    Expression<String>? displaySid,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (identityKey != null) 'identity_key': identityKey,
      if (gameCode != null) 'game_code': gameCode,
      if (generation != null) 'generation': generation,
      if (versionId != null) 'version_id': versionId,
      if (trainerName != null) 'trainer_name': trainerName,
      if (tid != null) 'tid': tid,
      if (sid != null) 'sid': sid,
      if (displayTid != null) 'display_tid': displayTid,
      if (displaySid != null) 'display_sid': displaySid,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SaveSlotsCompanion copyWith({
    Value<int>? id,
    Value<String>? identityKey,
    Value<String>? gameCode,
    Value<int>? generation,
    Value<int?>? versionId,
    Value<String>? trainerName,
    Value<int>? tid,
    Value<int?>? sid,
    Value<String>? displayTid,
    Value<String?>? displaySid,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SaveSlotsCompanion(
      id: id ?? this.id,
      identityKey: identityKey ?? this.identityKey,
      gameCode: gameCode ?? this.gameCode,
      generation: generation ?? this.generation,
      versionId: versionId ?? this.versionId,
      trainerName: trainerName ?? this.trainerName,
      tid: tid ?? this.tid,
      sid: sid ?? this.sid,
      displayTid: displayTid ?? this.displayTid,
      displaySid: displaySid ?? this.displaySid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (gameCode.present) {
      map['game_code'] = Variable<String>(gameCode.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<int>(versionId.value);
    }
    if (trainerName.present) {
      map['trainer_name'] = Variable<String>(trainerName.value);
    }
    if (tid.present) {
      map['tid'] = Variable<int>(tid.value);
    }
    if (sid.present) {
      map['sid'] = Variable<int>(sid.value);
    }
    if (displayTid.present) {
      map['display_tid'] = Variable<String>(displayTid.value);
    }
    if (displaySid.present) {
      map['display_sid'] = Variable<String>(displaySid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaveSlotsCompanion(')
          ..write('id: $id, ')
          ..write('identityKey: $identityKey, ')
          ..write('gameCode: $gameCode, ')
          ..write('generation: $generation, ')
          ..write('versionId: $versionId, ')
          ..write('trainerName: $trainerName, ')
          ..write('tid: $tid, ')
          ..write('sid: $sid, ')
          ..write('displayTid: $displayTid, ')
          ..write('displaySid: $displaySid, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SnapshotsTable extends Snapshots
    with TableInfo<$SnapshotsTable, Snapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<int> slotId = GeneratedColumn<int>(
    'slot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES save_slots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playTimeSecondsMeta = const VerificationMeta(
    'playTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> playTimeSeconds = GeneratedColumn<int>(
    'play_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trainerNameMeta = const VerificationMeta(
    'trainerName',
  );
  @override
  late final GeneratedColumn<String> trainerName = GeneratedColumn<String>(
    'trainer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameCodeMeta = const VerificationMeta(
    'gameCode',
  );
  @override
  late final GeneratedColumn<String> gameCode = GeneratedColumn<String>(
    'game_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<int> versionId = GeneratedColumn<int>(
    'version_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partySummaryMeta = const VerificationMeta(
    'partySummary',
  );
  @override
  late final GeneratedColumn<String> partySummary = GeneratedColumn<String>(
    'party_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxedCountMeta = const VerificationMeta(
    'boxedCount',
  );
  @override
  late final GeneratedColumn<int> boxedCount = GeneratedColumn<int>(
    'boxed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatInfoMeta = const VerificationMeta(
    'formatInfo',
  );
  @override
  late final GeneratedColumn<String> formatInfo = GeneratedColumn<String>(
    'format_info',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _problemMeta = const VerificationMeta(
    'problem',
  );
  @override
  late final GeneratedColumn<String> problem = GeneratedColumn<String>(
    'problem',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slotId,
    sha256,
    importedAt,
    fileName,
    origin,
    sourcePath,
    sizeBytes,
    playTimeSeconds,
    trainerName,
    gameCode,
    versionId,
    partySummary,
    boxedCount,
    formatInfo,
    checksum,
    note,
    relPath,
    deviceName,
    problem,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<Snapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('slot_id')) {
      context.handle(
        _slotIdMeta,
        slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('play_time_seconds')) {
      context.handle(
        _playTimeSecondsMeta,
        playTimeSeconds.isAcceptableOrUnknown(
          data['play_time_seconds']!,
          _playTimeSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playTimeSecondsMeta);
    }
    if (data.containsKey('trainer_name')) {
      context.handle(
        _trainerNameMeta,
        trainerName.isAcceptableOrUnknown(
          data['trainer_name']!,
          _trainerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trainerNameMeta);
    }
    if (data.containsKey('game_code')) {
      context.handle(
        _gameCodeMeta,
        gameCode.isAcceptableOrUnknown(data['game_code']!, _gameCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_gameCodeMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    }
    if (data.containsKey('party_summary')) {
      context.handle(
        _partySummaryMeta,
        partySummary.isAcceptableOrUnknown(
          data['party_summary']!,
          _partySummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_partySummaryMeta);
    }
    if (data.containsKey('boxed_count')) {
      context.handle(
        _boxedCountMeta,
        boxedCount.isAcceptableOrUnknown(data['boxed_count']!, _boxedCountMeta),
      );
    } else if (isInserting) {
      context.missing(_boxedCountMeta);
    }
    if (data.containsKey('format_info')) {
      context.handle(
        _formatInfoMeta,
        formatInfo.isAcceptableOrUnknown(data['format_info']!, _formatInfoMeta),
      );
    } else if (isInserting) {
      context.missing(_formatInfoMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    }
    if (data.containsKey('problem')) {
      context.handle(
        _problemMeta,
        problem.isAcceptableOrUnknown(data['problem']!, _problemMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {slotId, sha256},
  ];
  @override
  Snapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      slotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot_id'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      playTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_time_seconds'],
      )!,
      trainerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trainer_name'],
      )!,
      gameCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_code'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version_id'],
      ),
      partySummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_summary'],
      )!,
      boxedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}boxed_count'],
      )!,
      formatInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_info'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      ),
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      ),
      problem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem'],
      ),
    );
  }

  @override
  $SnapshotsTable createAlias(String alias) {
    return $SnapshotsTable(attachedDatabase, alias);
  }
}

class Snapshot extends DataClass implements Insertable<Snapshot> {
  final int id;
  final int slotId;
  final String sha256;
  final DateTime importedAt;
  final String fileName;

  /// file | folder | saf | demo | restore-backup | edit
  final String origin;

  /// Ruta (o URI SAF) de donde se importó, para restaurar en el mismo sitio.
  final String? sourcePath;
  final int sizeBytes;
  final int playTimeSeconds;
  final String trainerName;
  final String gameCode;
  final int? versionId;

  /// Especies del equipo: "25,6s,143" (s = variocolor).
  final String partySummary;
  final int boxedCount;
  final String formatInfo;
  final String checksum;

  /// Descripción de los cambios cuando el snapshot nace de una edición.
  final String? note;

  /// Ruta del save dentro de la carpeta del Arca (null en una base antigua).
  final String? relPath;

  /// Dispositivo que creó la copia.
  final String? deviceName;

  /// Problema detectado al leer la copia (tamaño o hash distintos…).
  final String? problem;
  const Snapshot({
    required this.id,
    required this.slotId,
    required this.sha256,
    required this.importedAt,
    required this.fileName,
    required this.origin,
    this.sourcePath,
    required this.sizeBytes,
    required this.playTimeSeconds,
    required this.trainerName,
    required this.gameCode,
    this.versionId,
    required this.partySummary,
    required this.boxedCount,
    required this.formatInfo,
    required this.checksum,
    this.note,
    this.relPath,
    this.deviceName,
    this.problem,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['slot_id'] = Variable<int>(slotId);
    map['sha256'] = Variable<String>(sha256);
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['file_name'] = Variable<String>(fileName);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['play_time_seconds'] = Variable<int>(playTimeSeconds);
    map['trainer_name'] = Variable<String>(trainerName);
    map['game_code'] = Variable<String>(gameCode);
    if (!nullToAbsent || versionId != null) {
      map['version_id'] = Variable<int>(versionId);
    }
    map['party_summary'] = Variable<String>(partySummary);
    map['boxed_count'] = Variable<int>(boxedCount);
    map['format_info'] = Variable<String>(formatInfo);
    map['checksum'] = Variable<String>(checksum);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || relPath != null) {
      map['rel_path'] = Variable<String>(relPath);
    }
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    if (!nullToAbsent || problem != null) {
      map['problem'] = Variable<String>(problem);
    }
    return map;
  }

  SnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotsCompanion(
      id: Value(id),
      slotId: Value(slotId),
      sha256: Value(sha256),
      importedAt: Value(importedAt),
      fileName: Value(fileName),
      origin: Value(origin),
      sourcePath: sourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePath),
      sizeBytes: Value(sizeBytes),
      playTimeSeconds: Value(playTimeSeconds),
      trainerName: Value(trainerName),
      gameCode: Value(gameCode),
      versionId: versionId == null && nullToAbsent
          ? const Value.absent()
          : Value(versionId),
      partySummary: Value(partySummary),
      boxedCount: Value(boxedCount),
      formatInfo: Value(formatInfo),
      checksum: Value(checksum),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      relPath: relPath == null && nullToAbsent
          ? const Value.absent()
          : Value(relPath),
      deviceName: deviceName == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceName),
      problem: problem == null && nullToAbsent
          ? const Value.absent()
          : Value(problem),
    );
  }

  factory Snapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snapshot(
      id: serializer.fromJson<int>(json['id']),
      slotId: serializer.fromJson<int>(json['slotId']),
      sha256: serializer.fromJson<String>(json['sha256']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      fileName: serializer.fromJson<String>(json['fileName']),
      origin: serializer.fromJson<String>(json['origin']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      playTimeSeconds: serializer.fromJson<int>(json['playTimeSeconds']),
      trainerName: serializer.fromJson<String>(json['trainerName']),
      gameCode: serializer.fromJson<String>(json['gameCode']),
      versionId: serializer.fromJson<int?>(json['versionId']),
      partySummary: serializer.fromJson<String>(json['partySummary']),
      boxedCount: serializer.fromJson<int>(json['boxedCount']),
      formatInfo: serializer.fromJson<String>(json['formatInfo']),
      checksum: serializer.fromJson<String>(json['checksum']),
      note: serializer.fromJson<String?>(json['note']),
      relPath: serializer.fromJson<String?>(json['relPath']),
      deviceName: serializer.fromJson<String?>(json['deviceName']),
      problem: serializer.fromJson<String?>(json['problem']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'slotId': serializer.toJson<int>(slotId),
      'sha256': serializer.toJson<String>(sha256),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'fileName': serializer.toJson<String>(fileName),
      'origin': serializer.toJson<String>(origin),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'playTimeSeconds': serializer.toJson<int>(playTimeSeconds),
      'trainerName': serializer.toJson<String>(trainerName),
      'gameCode': serializer.toJson<String>(gameCode),
      'versionId': serializer.toJson<int?>(versionId),
      'partySummary': serializer.toJson<String>(partySummary),
      'boxedCount': serializer.toJson<int>(boxedCount),
      'formatInfo': serializer.toJson<String>(formatInfo),
      'checksum': serializer.toJson<String>(checksum),
      'note': serializer.toJson<String?>(note),
      'relPath': serializer.toJson<String?>(relPath),
      'deviceName': serializer.toJson<String?>(deviceName),
      'problem': serializer.toJson<String?>(problem),
    };
  }

  Snapshot copyWith({
    int? id,
    int? slotId,
    String? sha256,
    DateTime? importedAt,
    String? fileName,
    String? origin,
    Value<String?> sourcePath = const Value.absent(),
    int? sizeBytes,
    int? playTimeSeconds,
    String? trainerName,
    String? gameCode,
    Value<int?> versionId = const Value.absent(),
    String? partySummary,
    int? boxedCount,
    String? formatInfo,
    String? checksum,
    Value<String?> note = const Value.absent(),
    Value<String?> relPath = const Value.absent(),
    Value<String?> deviceName = const Value.absent(),
    Value<String?> problem = const Value.absent(),
  }) => Snapshot(
    id: id ?? this.id,
    slotId: slotId ?? this.slotId,
    sha256: sha256 ?? this.sha256,
    importedAt: importedAt ?? this.importedAt,
    fileName: fileName ?? this.fileName,
    origin: origin ?? this.origin,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    playTimeSeconds: playTimeSeconds ?? this.playTimeSeconds,
    trainerName: trainerName ?? this.trainerName,
    gameCode: gameCode ?? this.gameCode,
    versionId: versionId.present ? versionId.value : this.versionId,
    partySummary: partySummary ?? this.partySummary,
    boxedCount: boxedCount ?? this.boxedCount,
    formatInfo: formatInfo ?? this.formatInfo,
    checksum: checksum ?? this.checksum,
    note: note.present ? note.value : this.note,
    relPath: relPath.present ? relPath.value : this.relPath,
    deviceName: deviceName.present ? deviceName.value : this.deviceName,
    problem: problem.present ? problem.value : this.problem,
  );
  Snapshot copyWithCompanion(SnapshotsCompanion data) {
    return Snapshot(
      id: data.id.present ? data.id.value : this.id,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      origin: data.origin.present ? data.origin.value : this.origin,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      playTimeSeconds: data.playTimeSeconds.present
          ? data.playTimeSeconds.value
          : this.playTimeSeconds,
      trainerName: data.trainerName.present
          ? data.trainerName.value
          : this.trainerName,
      gameCode: data.gameCode.present ? data.gameCode.value : this.gameCode,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      partySummary: data.partySummary.present
          ? data.partySummary.value
          : this.partySummary,
      boxedCount: data.boxedCount.present
          ? data.boxedCount.value
          : this.boxedCount,
      formatInfo: data.formatInfo.present
          ? data.formatInfo.value
          : this.formatInfo,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      note: data.note.present ? data.note.value : this.note,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      problem: data.problem.present ? data.problem.value : this.problem,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Snapshot(')
          ..write('id: $id, ')
          ..write('slotId: $slotId, ')
          ..write('sha256: $sha256, ')
          ..write('importedAt: $importedAt, ')
          ..write('fileName: $fileName, ')
          ..write('origin: $origin, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('playTimeSeconds: $playTimeSeconds, ')
          ..write('trainerName: $trainerName, ')
          ..write('gameCode: $gameCode, ')
          ..write('versionId: $versionId, ')
          ..write('partySummary: $partySummary, ')
          ..write('boxedCount: $boxedCount, ')
          ..write('formatInfo: $formatInfo, ')
          ..write('checksum: $checksum, ')
          ..write('note: $note, ')
          ..write('relPath: $relPath, ')
          ..write('deviceName: $deviceName, ')
          ..write('problem: $problem')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    slotId,
    sha256,
    importedAt,
    fileName,
    origin,
    sourcePath,
    sizeBytes,
    playTimeSeconds,
    trainerName,
    gameCode,
    versionId,
    partySummary,
    boxedCount,
    formatInfo,
    checksum,
    note,
    relPath,
    deviceName,
    problem,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Snapshot &&
          other.id == this.id &&
          other.slotId == this.slotId &&
          other.sha256 == this.sha256 &&
          other.importedAt == this.importedAt &&
          other.fileName == this.fileName &&
          other.origin == this.origin &&
          other.sourcePath == this.sourcePath &&
          other.sizeBytes == this.sizeBytes &&
          other.playTimeSeconds == this.playTimeSeconds &&
          other.trainerName == this.trainerName &&
          other.gameCode == this.gameCode &&
          other.versionId == this.versionId &&
          other.partySummary == this.partySummary &&
          other.boxedCount == this.boxedCount &&
          other.formatInfo == this.formatInfo &&
          other.checksum == this.checksum &&
          other.note == this.note &&
          other.relPath == this.relPath &&
          other.deviceName == this.deviceName &&
          other.problem == this.problem);
}

class SnapshotsCompanion extends UpdateCompanion<Snapshot> {
  final Value<int> id;
  final Value<int> slotId;
  final Value<String> sha256;
  final Value<DateTime> importedAt;
  final Value<String> fileName;
  final Value<String> origin;
  final Value<String?> sourcePath;
  final Value<int> sizeBytes;
  final Value<int> playTimeSeconds;
  final Value<String> trainerName;
  final Value<String> gameCode;
  final Value<int?> versionId;
  final Value<String> partySummary;
  final Value<int> boxedCount;
  final Value<String> formatInfo;
  final Value<String> checksum;
  final Value<String?> note;
  final Value<String?> relPath;
  final Value<String?> deviceName;
  final Value<String?> problem;
  const SnapshotsCompanion({
    this.id = const Value.absent(),
    this.slotId = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.fileName = const Value.absent(),
    this.origin = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.playTimeSeconds = const Value.absent(),
    this.trainerName = const Value.absent(),
    this.gameCode = const Value.absent(),
    this.versionId = const Value.absent(),
    this.partySummary = const Value.absent(),
    this.boxedCount = const Value.absent(),
    this.formatInfo = const Value.absent(),
    this.checksum = const Value.absent(),
    this.note = const Value.absent(),
    this.relPath = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.problem = const Value.absent(),
  });
  SnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required int slotId,
    required String sha256,
    required DateTime importedAt,
    required String fileName,
    required String origin,
    this.sourcePath = const Value.absent(),
    required int sizeBytes,
    required int playTimeSeconds,
    required String trainerName,
    required String gameCode,
    this.versionId = const Value.absent(),
    required String partySummary,
    required int boxedCount,
    required String formatInfo,
    required String checksum,
    this.note = const Value.absent(),
    this.relPath = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.problem = const Value.absent(),
  }) : slotId = Value(slotId),
       sha256 = Value(sha256),
       importedAt = Value(importedAt),
       fileName = Value(fileName),
       origin = Value(origin),
       sizeBytes = Value(sizeBytes),
       playTimeSeconds = Value(playTimeSeconds),
       trainerName = Value(trainerName),
       gameCode = Value(gameCode),
       partySummary = Value(partySummary),
       boxedCount = Value(boxedCount),
       formatInfo = Value(formatInfo),
       checksum = Value(checksum);
  static Insertable<Snapshot> custom({
    Expression<int>? id,
    Expression<int>? slotId,
    Expression<String>? sha256,
    Expression<DateTime>? importedAt,
    Expression<String>? fileName,
    Expression<String>? origin,
    Expression<String>? sourcePath,
    Expression<int>? sizeBytes,
    Expression<int>? playTimeSeconds,
    Expression<String>? trainerName,
    Expression<String>? gameCode,
    Expression<int>? versionId,
    Expression<String>? partySummary,
    Expression<int>? boxedCount,
    Expression<String>? formatInfo,
    Expression<String>? checksum,
    Expression<String>? note,
    Expression<String>? relPath,
    Expression<String>? deviceName,
    Expression<String>? problem,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slotId != null) 'slot_id': slotId,
      if (sha256 != null) 'sha256': sha256,
      if (importedAt != null) 'imported_at': importedAt,
      if (fileName != null) 'file_name': fileName,
      if (origin != null) 'origin': origin,
      if (sourcePath != null) 'source_path': sourcePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (playTimeSeconds != null) 'play_time_seconds': playTimeSeconds,
      if (trainerName != null) 'trainer_name': trainerName,
      if (gameCode != null) 'game_code': gameCode,
      if (versionId != null) 'version_id': versionId,
      if (partySummary != null) 'party_summary': partySummary,
      if (boxedCount != null) 'boxed_count': boxedCount,
      if (formatInfo != null) 'format_info': formatInfo,
      if (checksum != null) 'checksum': checksum,
      if (note != null) 'note': note,
      if (relPath != null) 'rel_path': relPath,
      if (deviceName != null) 'device_name': deviceName,
      if (problem != null) 'problem': problem,
    });
  }

  SnapshotsCompanion copyWith({
    Value<int>? id,
    Value<int>? slotId,
    Value<String>? sha256,
    Value<DateTime>? importedAt,
    Value<String>? fileName,
    Value<String>? origin,
    Value<String?>? sourcePath,
    Value<int>? sizeBytes,
    Value<int>? playTimeSeconds,
    Value<String>? trainerName,
    Value<String>? gameCode,
    Value<int?>? versionId,
    Value<String>? partySummary,
    Value<int>? boxedCount,
    Value<String>? formatInfo,
    Value<String>? checksum,
    Value<String?>? note,
    Value<String?>? relPath,
    Value<String?>? deviceName,
    Value<String?>? problem,
  }) {
    return SnapshotsCompanion(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      sha256: sha256 ?? this.sha256,
      importedAt: importedAt ?? this.importedAt,
      fileName: fileName ?? this.fileName,
      origin: origin ?? this.origin,
      sourcePath: sourcePath ?? this.sourcePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      playTimeSeconds: playTimeSeconds ?? this.playTimeSeconds,
      trainerName: trainerName ?? this.trainerName,
      gameCode: gameCode ?? this.gameCode,
      versionId: versionId ?? this.versionId,
      partySummary: partySummary ?? this.partySummary,
      boxedCount: boxedCount ?? this.boxedCount,
      formatInfo: formatInfo ?? this.formatInfo,
      checksum: checksum ?? this.checksum,
      note: note ?? this.note,
      relPath: relPath ?? this.relPath,
      deviceName: deviceName ?? this.deviceName,
      problem: problem ?? this.problem,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<int>(slotId.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (playTimeSeconds.present) {
      map['play_time_seconds'] = Variable<int>(playTimeSeconds.value);
    }
    if (trainerName.present) {
      map['trainer_name'] = Variable<String>(trainerName.value);
    }
    if (gameCode.present) {
      map['game_code'] = Variable<String>(gameCode.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<int>(versionId.value);
    }
    if (partySummary.present) {
      map['party_summary'] = Variable<String>(partySummary.value);
    }
    if (boxedCount.present) {
      map['boxed_count'] = Variable<int>(boxedCount.value);
    }
    if (formatInfo.present) {
      map['format_info'] = Variable<String>(formatInfo.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (problem.present) {
      map['problem'] = Variable<String>(problem.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('slotId: $slotId, ')
          ..write('sha256: $sha256, ')
          ..write('importedAt: $importedAt, ')
          ..write('fileName: $fileName, ')
          ..write('origin: $origin, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('playTimeSeconds: $playTimeSeconds, ')
          ..write('trainerName: $trainerName, ')
          ..write('gameCode: $gameCode, ')
          ..write('versionId: $versionId, ')
          ..write('partySummary: $partySummary, ')
          ..write('boxedCount: $boxedCount, ')
          ..write('formatInfo: $formatInfo, ')
          ..write('checksum: $checksum, ')
          ..write('note: $note, ')
          ..write('relPath: $relPath, ')
          ..write('deviceName: $deviceName, ')
          ..write('problem: $problem')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ArcaDatabase extends GeneratedDatabase {
  _$ArcaDatabase(QueryExecutor e) : super(e);
  $ArcaDatabaseManager get managers => $ArcaDatabaseManager(this);
  late final $SaveSlotsTable saveSlots = $SaveSlotsTable(this);
  late final $SnapshotsTable snapshots = $SnapshotsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    saveSlots,
    snapshots,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'save_slots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('snapshots', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SaveSlotsTableCreateCompanionBuilder =
    SaveSlotsCompanion Function({
      Value<int> id,
      required String identityKey,
      required String gameCode,
      required int generation,
      Value<int?> versionId,
      required String trainerName,
      required int tid,
      Value<int?> sid,
      required String displayTid,
      Value<String?> displaySid,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$SaveSlotsTableUpdateCompanionBuilder =
    SaveSlotsCompanion Function({
      Value<int> id,
      Value<String> identityKey,
      Value<String> gameCode,
      Value<int> generation,
      Value<int?> versionId,
      Value<String> trainerName,
      Value<int> tid,
      Value<int?> sid,
      Value<String> displayTid,
      Value<String?> displaySid,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$SaveSlotsTableReferences
    extends BaseReferences<_$ArcaDatabase, $SaveSlotsTable, SaveSlot> {
  $$SaveSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SnapshotsTable, List<Snapshot>>
  _snapshotsRefsTable(_$ArcaDatabase db) => MultiTypedResultKey.fromTable(
    db.snapshots,
    aliasName: 'save_slots__id__snapshots__slot_id',
  );

  $$SnapshotsTableProcessedTableManager get snapshotsRefs {
    final manager = $$SnapshotsTableTableManager(
      $_db,
      $_db.snapshots,
    ).filter((f) => f.slotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_snapshotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SaveSlotsTableFilterComposer
    extends Composer<_$ArcaDatabase, $SaveSlotsTable> {
  $$SaveSlotsTableFilterComposer({
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

  ColumnFilters<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameCode => $composableBuilder(
    column: $table.gameCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tid => $composableBuilder(
    column: $table.tid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sid => $composableBuilder(
    column: $table.sid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayTid => $composableBuilder(
    column: $table.displayTid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displaySid => $composableBuilder(
    column: $table.displaySid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> snapshotsRefs(
    Expression<bool> Function($$SnapshotsTableFilterComposer f) f,
  ) {
    final $$SnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SaveSlotsTableOrderingComposer
    extends Composer<_$ArcaDatabase, $SaveSlotsTable> {
  $$SaveSlotsTableOrderingComposer({
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

  ColumnOrderings<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameCode => $composableBuilder(
    column: $table.gameCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tid => $composableBuilder(
    column: $table.tid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sid => $composableBuilder(
    column: $table.sid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayTid => $composableBuilder(
    column: $table.displayTid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displaySid => $composableBuilder(
    column: $table.displaySid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SaveSlotsTableAnnotationComposer
    extends Composer<_$ArcaDatabase, $SaveSlotsTable> {
  $$SaveSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameCode =>
      $composableBuilder(column: $table.gameCode, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tid =>
      $composableBuilder(column: $table.tid, builder: (column) => column);

  GeneratedColumn<int> get sid =>
      $composableBuilder(column: $table.sid, builder: (column) => column);

  GeneratedColumn<String> get displayTid => $composableBuilder(
    column: $table.displayTid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displaySid => $composableBuilder(
    column: $table.displaySid,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> snapshotsRefs<T extends Object>(
    Expression<T> Function($$SnapshotsTableAnnotationComposer a) f,
  ) {
    final $$SnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.slotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SaveSlotsTableTableManager
    extends
        RootTableManager<
          _$ArcaDatabase,
          $SaveSlotsTable,
          SaveSlot,
          $$SaveSlotsTableFilterComposer,
          $$SaveSlotsTableOrderingComposer,
          $$SaveSlotsTableAnnotationComposer,
          $$SaveSlotsTableCreateCompanionBuilder,
          $$SaveSlotsTableUpdateCompanionBuilder,
          (SaveSlot, $$SaveSlotsTableReferences),
          SaveSlot,
          PrefetchHooks Function({bool snapshotsRefs})
        > {
  $$SaveSlotsTableTableManager(_$ArcaDatabase db, $SaveSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaveSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaveSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaveSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> identityKey = const Value.absent(),
                Value<String> gameCode = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int?> versionId = const Value.absent(),
                Value<String> trainerName = const Value.absent(),
                Value<int> tid = const Value.absent(),
                Value<int?> sid = const Value.absent(),
                Value<String> displayTid = const Value.absent(),
                Value<String?> displaySid = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SaveSlotsCompanion(
                id: id,
                identityKey: identityKey,
                gameCode: gameCode,
                generation: generation,
                versionId: versionId,
                trainerName: trainerName,
                tid: tid,
                sid: sid,
                displayTid: displayTid,
                displaySid: displaySid,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String identityKey,
                required String gameCode,
                required int generation,
                Value<int?> versionId = const Value.absent(),
                required String trainerName,
                required int tid,
                Value<int?> sid = const Value.absent(),
                required String displayTid,
                Value<String?> displaySid = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => SaveSlotsCompanion.insert(
                id: id,
                identityKey: identityKey,
                gameCode: gameCode,
                generation: generation,
                versionId: versionId,
                trainerName: trainerName,
                tid: tid,
                sid: sid,
                displayTid: displayTid,
                displaySid: displaySid,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SaveSlotsTable, SaveSlot>(table),
                  $$SaveSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (snapshotsRefs) db.snapshots],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (snapshotsRefs)
                    await $_getPrefetchedDataByColumns<
                      SaveSlot,
                      $SaveSlotsTable,
                      Snapshot,
                      $SnapshotsTable
                    >(
                      currentTable: table,
                      referencedTable: $$SaveSlotsTableReferences
                          ._snapshotsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SaveSlotsTableReferences(
                            db,
                            table,
                            p0,
                          ).snapshotsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'slot_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SaveSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$ArcaDatabase,
      $SaveSlotsTable,
      SaveSlot,
      $$SaveSlotsTableFilterComposer,
      $$SaveSlotsTableOrderingComposer,
      $$SaveSlotsTableAnnotationComposer,
      $$SaveSlotsTableCreateCompanionBuilder,
      $$SaveSlotsTableUpdateCompanionBuilder,
      (SaveSlot, $$SaveSlotsTableReferences),
      SaveSlot,
      PrefetchHooks Function({bool snapshotsRefs})
    >;
typedef $$SnapshotsTableCreateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      required int slotId,
      required String sha256,
      required DateTime importedAt,
      required String fileName,
      required String origin,
      Value<String?> sourcePath,
      required int sizeBytes,
      required int playTimeSeconds,
      required String trainerName,
      required String gameCode,
      Value<int?> versionId,
      required String partySummary,
      required int boxedCount,
      required String formatInfo,
      required String checksum,
      Value<String?> note,
      Value<String?> relPath,
      Value<String?> deviceName,
      Value<String?> problem,
    });
typedef $$SnapshotsTableUpdateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      Value<int> slotId,
      Value<String> sha256,
      Value<DateTime> importedAt,
      Value<String> fileName,
      Value<String> origin,
      Value<String?> sourcePath,
      Value<int> sizeBytes,
      Value<int> playTimeSeconds,
      Value<String> trainerName,
      Value<String> gameCode,
      Value<int?> versionId,
      Value<String> partySummary,
      Value<int> boxedCount,
      Value<String> formatInfo,
      Value<String> checksum,
      Value<String?> note,
      Value<String?> relPath,
      Value<String?> deviceName,
      Value<String?> problem,
    });

final class $$SnapshotsTableReferences
    extends BaseReferences<_$ArcaDatabase, $SnapshotsTable, Snapshot> {
  $$SnapshotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SaveSlotsTable _slotIdTable(_$ArcaDatabase db) =>
      db.saveSlots.createAlias('snapshots__slot_id__save_slots__id');

  $$SaveSlotsTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<int>('slot_id')!;

    final manager = $$SaveSlotsTableTableManager(
      $_db,
      $_db.saveSlots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SnapshotsTableFilterComposer
    extends Composer<_$ArcaDatabase, $SnapshotsTable> {
  $$SnapshotsTableFilterComposer({
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

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playTimeSeconds => $composableBuilder(
    column: $table.playTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameCode => $composableBuilder(
    column: $table.gameCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partySummary => $composableBuilder(
    column: $table.partySummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boxedCount => $composableBuilder(
    column: $table.boxedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatInfo => $composableBuilder(
    column: $table.formatInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get problem => $composableBuilder(
    column: $table.problem,
    builder: (column) => ColumnFilters(column),
  );

  $$SaveSlotsTableFilterComposer get slotId {
    final $$SaveSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.saveSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaveSlotsTableFilterComposer(
            $db: $db,
            $table: $db.saveSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotsTableOrderingComposer
    extends Composer<_$ArcaDatabase, $SnapshotsTable> {
  $$SnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playTimeSeconds => $composableBuilder(
    column: $table.playTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameCode => $composableBuilder(
    column: $table.gameCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partySummary => $composableBuilder(
    column: $table.partySummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boxedCount => $composableBuilder(
    column: $table.boxedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatInfo => $composableBuilder(
    column: $table.formatInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get problem => $composableBuilder(
    column: $table.problem,
    builder: (column) => ColumnOrderings(column),
  );

  $$SaveSlotsTableOrderingComposer get slotId {
    final $$SaveSlotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.saveSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaveSlotsTableOrderingComposer(
            $db: $db,
            $table: $db.saveSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotsTableAnnotationComposer
    extends Composer<_$ArcaDatabase, $SnapshotsTable> {
  $$SnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get playTimeSeconds => $composableBuilder(
    column: $table.playTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trainerName => $composableBuilder(
    column: $table.trainerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameCode =>
      $composableBuilder(column: $table.gameCode, builder: (column) => column);

  GeneratedColumn<int> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get partySummary => $composableBuilder(
    column: $table.partySummary,
    builder: (column) => column,
  );

  GeneratedColumn<int> get boxedCount => $composableBuilder(
    column: $table.boxedCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formatInfo => $composableBuilder(
    column: $table.formatInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get problem =>
      $composableBuilder(column: $table.problem, builder: (column) => column);

  $$SaveSlotsTableAnnotationComposer get slotId {
    final $$SaveSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.slotId,
      referencedTable: $db.saveSlots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaveSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.saveSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SnapshotsTableTableManager
    extends
        RootTableManager<
          _$ArcaDatabase,
          $SnapshotsTable,
          Snapshot,
          $$SnapshotsTableFilterComposer,
          $$SnapshotsTableOrderingComposer,
          $$SnapshotsTableAnnotationComposer,
          $$SnapshotsTableCreateCompanionBuilder,
          $$SnapshotsTableUpdateCompanionBuilder,
          (Snapshot, $$SnapshotsTableReferences),
          Snapshot,
          PrefetchHooks Function({bool slotId})
        > {
  $$SnapshotsTableTableManager(_$ArcaDatabase db, $SnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> slotId = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> playTimeSeconds = const Value.absent(),
                Value<String> trainerName = const Value.absent(),
                Value<String> gameCode = const Value.absent(),
                Value<int?> versionId = const Value.absent(),
                Value<String> partySummary = const Value.absent(),
                Value<int> boxedCount = const Value.absent(),
                Value<String> formatInfo = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> relPath = const Value.absent(),
                Value<String?> deviceName = const Value.absent(),
                Value<String?> problem = const Value.absent(),
              }) => SnapshotsCompanion(
                id: id,
                slotId: slotId,
                sha256: sha256,
                importedAt: importedAt,
                fileName: fileName,
                origin: origin,
                sourcePath: sourcePath,
                sizeBytes: sizeBytes,
                playTimeSeconds: playTimeSeconds,
                trainerName: trainerName,
                gameCode: gameCode,
                versionId: versionId,
                partySummary: partySummary,
                boxedCount: boxedCount,
                formatInfo: formatInfo,
                checksum: checksum,
                note: note,
                relPath: relPath,
                deviceName: deviceName,
                problem: problem,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int slotId,
                required String sha256,
                required DateTime importedAt,
                required String fileName,
                required String origin,
                Value<String?> sourcePath = const Value.absent(),
                required int sizeBytes,
                required int playTimeSeconds,
                required String trainerName,
                required String gameCode,
                Value<int?> versionId = const Value.absent(),
                required String partySummary,
                required int boxedCount,
                required String formatInfo,
                required String checksum,
                Value<String?> note = const Value.absent(),
                Value<String?> relPath = const Value.absent(),
                Value<String?> deviceName = const Value.absent(),
                Value<String?> problem = const Value.absent(),
              }) => SnapshotsCompanion.insert(
                id: id,
                slotId: slotId,
                sha256: sha256,
                importedAt: importedAt,
                fileName: fileName,
                origin: origin,
                sourcePath: sourcePath,
                sizeBytes: sizeBytes,
                playTimeSeconds: playTimeSeconds,
                trainerName: trainerName,
                gameCode: gameCode,
                versionId: versionId,
                partySummary: partySummary,
                boxedCount: boxedCount,
                formatInfo: formatInfo,
                checksum: checksum,
                note: note,
                relPath: relPath,
                deviceName: deviceName,
                problem: problem,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SnapshotsTable, Snapshot>(table),
                  $$SnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({slotId = false}) {
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
                    if (slotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.slotId,
                                referencedTable: $$SnapshotsTableReferences
                                    ._slotIdTable(db),
                                referencedColumn: $$SnapshotsTableReferences
                                    ._slotIdTable(db)
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

typedef $$SnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$ArcaDatabase,
      $SnapshotsTable,
      Snapshot,
      $$SnapshotsTableFilterComposer,
      $$SnapshotsTableOrderingComposer,
      $$SnapshotsTableAnnotationComposer,
      $$SnapshotsTableCreateCompanionBuilder,
      $$SnapshotsTableUpdateCompanionBuilder,
      (Snapshot, $$SnapshotsTableReferences),
      Snapshot,
      PrefetchHooks Function({bool slotId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$ArcaDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$ArcaDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$ArcaDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$ArcaDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$ArcaDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$ArcaDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$ArcaDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$ArcaDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$ArcaDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $ArcaDatabaseManager {
  final _$ArcaDatabase _db;
  $ArcaDatabaseManager(this._db);
  $$SaveSlotsTableTableManager get saveSlots =>
      $$SaveSlotsTableTableManager(_db, _db.saveSlots);
  $$SnapshotsTableTableManager get snapshots =>
      $$SnapshotsTableTableManager(_db, _db.snapshots);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
