// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Activities extends Table with TableInfo<Activities, ActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Activities(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _colorSeedMeta = const VerificationMeta(
    'colorSeed',
  );
  late final GeneratedColumn<int> colorSeed = GeneratedColumn<int>(
    'color_seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  late final GeneratedColumn<int> archived = GeneratedColumn<int>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameKey,
    colorSeed,
    archived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('color_seed')) {
      context.handle(
        _colorSeedMeta,
        colorSeed.isAcceptableOrUnknown(data['color_seed']!, _colorSeedMeta),
      );
    } else if (isInserting) {
      context.missing(_colorSeedMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
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
  ActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      colorSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_seed'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Activities createAlias(String alias) {
    return Activities(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ActivityRow extends DataClass implements Insertable<ActivityRow> {
  final String id;
  final String name;
  final String nameKey;
  final int colorSeed;
  final int archived;
  final int createdAt;
  final int updatedAt;
  const ActivityRow({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.colorSeed,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['name_key'] = Variable<String>(nameKey);
    map['color_seed'] = Variable<int>(colorSeed);
    map['archived'] = Variable<int>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      name: Value(name),
      nameKey: Value(nameKey),
      colorSeed: Value(colorSeed),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameKey: serializer.fromJson<String>(json['name_key']),
      colorSeed: serializer.fromJson<int>(json['color_seed']),
      archived: serializer.fromJson<int>(json['archived']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'name_key': serializer.toJson<String>(nameKey),
      'color_seed': serializer.toJson<int>(colorSeed),
      'archived': serializer.toJson<int>(archived),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  ActivityRow copyWith({
    String? id,
    String? name,
    String? nameKey,
    int? colorSeed,
    int? archived,
    int? createdAt,
    int? updatedAt,
  }) => ActivityRow(
    id: id ?? this.id,
    name: name ?? this.name,
    nameKey: nameKey ?? this.nameKey,
    colorSeed: colorSeed ?? this.colorSeed,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActivityRow copyWithCompanion(ActivitiesCompanion data) {
    return ActivityRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      colorSeed: data.colorSeed.present ? data.colorSeed.value : this.colorSeed,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('colorSeed: $colorSeed, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, nameKey, colorSeed, archived, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameKey == this.nameKey &&
          other.colorSeed == this.colorSeed &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ActivitiesCompanion extends UpdateCompanion<ActivityRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nameKey;
  final Value<int> colorSeed;
  final Value<int> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.colorSeed = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    required String id,
    required String name,
    required String nameKey,
    required int colorSeed,
    this.archived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       nameKey = Value(nameKey),
       colorSeed = Value(colorSeed),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ActivityRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nameKey,
    Expression<int>? colorSeed,
    Expression<int>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameKey != null) 'name_key': nameKey,
      if (colorSeed != null) 'color_seed': colorSeed,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nameKey,
    Value<int>? colorSeed,
    Value<int>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      colorSeed: colorSeed ?? this.colorSeed,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (colorSeed.present) {
      map['color_seed'] = Variable<int>(colorSeed.value);
    }
    if (archived.present) {
      map['archived'] = Variable<int>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('colorSeed: $colorSeed, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class TimeEntries extends Table with TableInfo<TimeEntries, TimeEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TimeEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES activities(id)',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  late final GeneratedColumn<int> startUtc = GeneratedColumn<int>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  late final GeneratedColumn<int> endUtc = GeneratedColumn<int>(
    'end_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _tzNameMeta = const VerificationMeta('tzName');
  late final GeneratedColumn<String> tzName = GeneratedColumn<String>(
    'tz_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _isRunningMeta = const VerificationMeta(
    'isRunning',
  );
  late final GeneratedColumn<int> isRunning = GeneratedColumn<int>(
    'is_running',
    aliasedName,
    true,
    generatedAs: GeneratedAs(
      const CustomExpression(
        'CASE WHEN end_utc IS NULL AND deleted_at IS NULL THEN 1 END',
      ),
      false,
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'GENERATED ALWAYS AS (CASE WHEN end_utc IS NULL AND deleted_at IS NULL THEN 1 END) VIRTUAL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityId,
    note,
    startUtc,
    endUtc,
    tzName,
    createdAt,
    updatedAt,
    deletedAt,
    isRunning,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    }
    if (data.containsKey('tz_name')) {
      context.handle(
        _tzNameMeta,
        tzName.isAcceptableOrUnknown(data['tz_name']!, _tzNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tzNameMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_running')) {
      context.handle(
        _isRunningMeta,
        isRunning.isAcceptableOrUnknown(data['is_running']!, _isRunningMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc'],
      ),
      tzName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      isRunning: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_running'],
      ),
    );
  }

  @override
  TimeEntries createAlias(String alias) {
    return TimeEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK(end_utc IS NULL OR end_utc > start_utc)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class TimeEntryRow extends DataClass implements Insertable<TimeEntryRow> {
  final String id;
  final String activityId;
  final String? note;
  final int startUtc;
  final int? endUtc;
  final String tzName;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  /// 1 only while this row is the live running entry, NULL otherwise.
  final int? isRunning;
  const TimeEntryRow({
    required this.id,
    required this.activityId,
    this.note,
    required this.startUtc,
    this.endUtc,
    required this.tzName,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isRunning,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_id'] = Variable<String>(activityId);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['start_utc'] = Variable<int>(startUtc);
    if (!nullToAbsent || endUtc != null) {
      map['end_utc'] = Variable<int>(endUtc);
    }
    map['tz_name'] = Variable<String>(tzName);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TimeEntriesCompanion toCompanion(bool nullToAbsent) {
    return TimeEntriesCompanion(
      id: Value(id),
      activityId: Value(activityId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      startUtc: Value(startUtc),
      endUtc: endUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(endUtc),
      tzName: Value(tzName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TimeEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeEntryRow(
      id: serializer.fromJson<String>(json['id']),
      activityId: serializer.fromJson<String>(json['activity_id']),
      note: serializer.fromJson<String?>(json['note']),
      startUtc: serializer.fromJson<int>(json['start_utc']),
      endUtc: serializer.fromJson<int?>(json['end_utc']),
      tzName: serializer.fromJson<String>(json['tz_name']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
      isRunning: serializer.fromJson<int?>(json['is_running']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activity_id': serializer.toJson<String>(activityId),
      'note': serializer.toJson<String?>(note),
      'start_utc': serializer.toJson<int>(startUtc),
      'end_utc': serializer.toJson<int?>(endUtc),
      'tz_name': serializer.toJson<String>(tzName),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'deleted_at': serializer.toJson<int?>(deletedAt),
      'is_running': serializer.toJson<int?>(isRunning),
    };
  }

  TimeEntryRow copyWith({
    String? id,
    String? activityId,
    Value<String?> note = const Value.absent(),
    int? startUtc,
    Value<int?> endUtc = const Value.absent(),
    String? tzName,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    Value<int?> isRunning = const Value.absent(),
  }) => TimeEntryRow(
    id: id ?? this.id,
    activityId: activityId ?? this.activityId,
    note: note.present ? note.value : this.note,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc.present ? endUtc.value : this.endUtc,
    tzName: tzName ?? this.tzName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isRunning: isRunning.present ? isRunning.value : this.isRunning,
  );
  @override
  String toString() {
    return (StringBuffer('TimeEntryRow(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('note: $note, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('tzName: $tzName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isRunning: $isRunning')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityId,
    note,
    startUtc,
    endUtc,
    tzName,
    createdAt,
    updatedAt,
    deletedAt,
    isRunning,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeEntryRow &&
          other.id == this.id &&
          other.activityId == this.activityId &&
          other.note == this.note &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.tzName == this.tzName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.isRunning == this.isRunning);
}

class TimeEntriesCompanion extends UpdateCompanion<TimeEntryRow> {
  final Value<String> id;
  final Value<String> activityId;
  final Value<String?> note;
  final Value<int> startUtc;
  final Value<int?> endUtc;
  final Value<String> tzName;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const TimeEntriesCompanion({
    this.id = const Value.absent(),
    this.activityId = const Value.absent(),
    this.note = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.tzName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimeEntriesCompanion.insert({
    required String id,
    required String activityId,
    this.note = const Value.absent(),
    required int startUtc,
    this.endUtc = const Value.absent(),
    required String tzName,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityId = Value(activityId),
       startUtc = Value(startUtc),
       tzName = Value(tzName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TimeEntryRow> custom({
    Expression<String>? id,
    Expression<String>? activityId,
    Expression<String>? note,
    Expression<int>? startUtc,
    Expression<int>? endUtc,
    Expression<String>? tzName,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityId != null) 'activity_id': activityId,
      if (note != null) 'note': note,
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (tzName != null) 'tz_name': tzName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimeEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? activityId,
    Value<String?>? note,
    Value<int>? startUtc,
    Value<int?>? endUtc,
    Value<String>? tzName,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TimeEntriesCompanion(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      note: note ?? this.note,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      tzName: tzName ?? this.tzName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<int>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<int>(endUtc.value);
    }
    if (tzName.present) {
      map['tz_name'] = Variable<String>(tzName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeEntriesCompanion(')
          ..write('id: $id, ')
          ..write('activityId: $activityId, ')
          ..write('note: $note, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('tzName: $tzName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SettingsRow extends Table with TableInfo<SettingsRow, SettingsRowData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SettingsRow(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _snapMinutesMeta = const VerificationMeta(
    'snapMinutes',
  );
  late final GeneratedColumn<int> snapMinutes = GeneratedColumn<int>(
    'snap_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 5',
    defaultValue: const CustomExpression('5'),
  );
  static const VerificationMeta _use24HourClockMeta = const VerificationMeta(
    'use24HourClock',
  );
  late final GeneratedColumn<int> use24HourClock = GeneratedColumn<int>(
    'use24HourClock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'system\'',
    defaultValue: const CustomExpression('\'system\''),
  );
  static const VerificationMeta _pixelsPerHourMeta = const VerificationMeta(
    'pixelsPerHour',
  );
  late final GeneratedColumn<double> pixelsPerHour = GeneratedColumn<double>(
    'pixels_per_hour',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 72.0',
    defaultValue: const CustomExpression('72.0'),
  );
  static const VerificationMeta _continueMinutesMeta = const VerificationMeta(
    'continueMinutes',
  );
  late final GeneratedColumn<int> continueMinutes = GeneratedColumn<int>(
    'continue_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 5',
    defaultValue: const CustomExpression('5'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapMinutes,
    use24HourClock,
    themeMode,
    pixelsPerHour,
    continueMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_row';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRowData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('snap_minutes')) {
      context.handle(
        _snapMinutesMeta,
        snapMinutes.isAcceptableOrUnknown(
          data['snap_minutes']!,
          _snapMinutesMeta,
        ),
      );
    }
    if (data.containsKey('use24HourClock')) {
      context.handle(
        _use24HourClockMeta,
        use24HourClock.isAcceptableOrUnknown(
          data['use24HourClock']!,
          _use24HourClockMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('pixels_per_hour')) {
      context.handle(
        _pixelsPerHourMeta,
        pixelsPerHour.isAcceptableOrUnknown(
          data['pixels_per_hour']!,
          _pixelsPerHourMeta,
        ),
      );
    }
    if (data.containsKey('continue_minutes')) {
      context.handle(
        _continueMinutesMeta,
        continueMinutes.isAcceptableOrUnknown(
          data['continue_minutes']!,
          _continueMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRowData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRowData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      snapMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snap_minutes'],
      )!,
      use24HourClock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use24HourClock'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      pixelsPerHour: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pixels_per_hour'],
      )!,
      continueMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}continue_minutes'],
      )!,
    );
  }

  @override
  SettingsRow createAlias(String alias) {
    return SettingsRow(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['CHECK(id = 1)'];
  @override
  bool get dontWriteConstraints => true;
}

class SettingsRowData extends DataClass implements Insertable<SettingsRowData> {
  final int id;
  final int snapMinutes;
  final int use24HourClock;
  final String themeMode;
  final double pixelsPerHour;
  final int continueMinutes;
  const SettingsRowData({
    required this.id,
    required this.snapMinutes,
    required this.use24HourClock,
    required this.themeMode,
    required this.pixelsPerHour,
    required this.continueMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['snap_minutes'] = Variable<int>(snapMinutes);
    map['use24HourClock'] = Variable<int>(use24HourClock);
    map['theme_mode'] = Variable<String>(themeMode);
    map['pixels_per_hour'] = Variable<double>(pixelsPerHour);
    map['continue_minutes'] = Variable<int>(continueMinutes);
    return map;
  }

  SettingsRowCompanion toCompanion(bool nullToAbsent) {
    return SettingsRowCompanion(
      id: Value(id),
      snapMinutes: Value(snapMinutes),
      use24HourClock: Value(use24HourClock),
      themeMode: Value(themeMode),
      pixelsPerHour: Value(pixelsPerHour),
      continueMinutes: Value(continueMinutes),
    );
  }

  factory SettingsRowData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRowData(
      id: serializer.fromJson<int>(json['id']),
      snapMinutes: serializer.fromJson<int>(json['snap_minutes']),
      use24HourClock: serializer.fromJson<int>(json['use24HourClock']),
      themeMode: serializer.fromJson<String>(json['theme_mode']),
      pixelsPerHour: serializer.fromJson<double>(json['pixels_per_hour']),
      continueMinutes: serializer.fromJson<int>(json['continue_minutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'snap_minutes': serializer.toJson<int>(snapMinutes),
      'use24HourClock': serializer.toJson<int>(use24HourClock),
      'theme_mode': serializer.toJson<String>(themeMode),
      'pixels_per_hour': serializer.toJson<double>(pixelsPerHour),
      'continue_minutes': serializer.toJson<int>(continueMinutes),
    };
  }

  SettingsRowData copyWith({
    int? id,
    int? snapMinutes,
    int? use24HourClock,
    String? themeMode,
    double? pixelsPerHour,
    int? continueMinutes,
  }) => SettingsRowData(
    id: id ?? this.id,
    snapMinutes: snapMinutes ?? this.snapMinutes,
    use24HourClock: use24HourClock ?? this.use24HourClock,
    themeMode: themeMode ?? this.themeMode,
    pixelsPerHour: pixelsPerHour ?? this.pixelsPerHour,
    continueMinutes: continueMinutes ?? this.continueMinutes,
  );
  SettingsRowData copyWithCompanion(SettingsRowCompanion data) {
    return SettingsRowData(
      id: data.id.present ? data.id.value : this.id,
      snapMinutes: data.snapMinutes.present
          ? data.snapMinutes.value
          : this.snapMinutes,
      use24HourClock: data.use24HourClock.present
          ? data.use24HourClock.value
          : this.use24HourClock,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      pixelsPerHour: data.pixelsPerHour.present
          ? data.pixelsPerHour.value
          : this.pixelsPerHour,
      continueMinutes: data.continueMinutes.present
          ? data.continueMinutes.value
          : this.continueMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowData(')
          ..write('id: $id, ')
          ..write('snapMinutes: $snapMinutes, ')
          ..write('use24HourClock: $use24HourClock, ')
          ..write('themeMode: $themeMode, ')
          ..write('pixelsPerHour: $pixelsPerHour, ')
          ..write('continueMinutes: $continueMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapMinutes,
    use24HourClock,
    themeMode,
    pixelsPerHour,
    continueMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRowData &&
          other.id == this.id &&
          other.snapMinutes == this.snapMinutes &&
          other.use24HourClock == this.use24HourClock &&
          other.themeMode == this.themeMode &&
          other.pixelsPerHour == this.pixelsPerHour &&
          other.continueMinutes == this.continueMinutes);
}

class SettingsRowCompanion extends UpdateCompanion<SettingsRowData> {
  final Value<int> id;
  final Value<int> snapMinutes;
  final Value<int> use24HourClock;
  final Value<String> themeMode;
  final Value<double> pixelsPerHour;
  final Value<int> continueMinutes;
  const SettingsRowCompanion({
    this.id = const Value.absent(),
    this.snapMinutes = const Value.absent(),
    this.use24HourClock = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.pixelsPerHour = const Value.absent(),
    this.continueMinutes = const Value.absent(),
  });
  SettingsRowCompanion.insert({
    this.id = const Value.absent(),
    this.snapMinutes = const Value.absent(),
    this.use24HourClock = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.pixelsPerHour = const Value.absent(),
    this.continueMinutes = const Value.absent(),
  });
  static Insertable<SettingsRowData> custom({
    Expression<int>? id,
    Expression<int>? snapMinutes,
    Expression<int>? use24HourClock,
    Expression<String>? themeMode,
    Expression<double>? pixelsPerHour,
    Expression<int>? continueMinutes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapMinutes != null) 'snap_minutes': snapMinutes,
      if (use24HourClock != null) 'use24HourClock': use24HourClock,
      if (themeMode != null) 'theme_mode': themeMode,
      if (pixelsPerHour != null) 'pixels_per_hour': pixelsPerHour,
      if (continueMinutes != null) 'continue_minutes': continueMinutes,
    });
  }

  SettingsRowCompanion copyWith({
    Value<int>? id,
    Value<int>? snapMinutes,
    Value<int>? use24HourClock,
    Value<String>? themeMode,
    Value<double>? pixelsPerHour,
    Value<int>? continueMinutes,
  }) {
    return SettingsRowCompanion(
      id: id ?? this.id,
      snapMinutes: snapMinutes ?? this.snapMinutes,
      use24HourClock: use24HourClock ?? this.use24HourClock,
      themeMode: themeMode ?? this.themeMode,
      pixelsPerHour: pixelsPerHour ?? this.pixelsPerHour,
      continueMinutes: continueMinutes ?? this.continueMinutes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (snapMinutes.present) {
      map['snap_minutes'] = Variable<int>(snapMinutes.value);
    }
    if (use24HourClock.present) {
      map['use24HourClock'] = Variable<int>(use24HourClock.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (pixelsPerHour.present) {
      map['pixels_per_hour'] = Variable<double>(pixelsPerHour.value);
    }
    if (continueMinutes.present) {
      map['continue_minutes'] = Variable<int>(continueMinutes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowCompanion(')
          ..write('id: $id, ')
          ..write('snapMinutes: $snapMinutes, ')
          ..write('use24HourClock: $use24HourClock, ')
          ..write('themeMode: $themeMode, ')
          ..write('pixelsPerHour: $pixelsPerHour, ')
          ..write('continueMinutes: $continueMinutes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Activities activities = Activities(this);
  late final TimeEntries timeEntries = TimeEntries(this);
  late final Index uxEntriesSingleRunning = Index(
    'ux_entries_single_running',
    'CREATE UNIQUE INDEX ux_entries_single_running ON time_entries (is_running)',
  );
  late final Index ixEntriesStart = Index(
    'ix_entries_start',
    'CREATE INDEX ix_entries_start ON time_entries (start_utc)',
  );
  late final Index ixEntriesActivityStart = Index(
    'ix_entries_activity_start',
    'CREATE INDEX ix_entries_activity_start ON time_entries (activity_id, start_utc)',
  );
  late final SettingsRow settingsRow = SettingsRow(this);
  Selectable<TimeEntryRow> entriesInRange(int rangeEnd, int? rangeStart) {
    return customSelect(
      'SELECT * FROM time_entries WHERE deleted_at IS NULL AND start_utc < ?1 AND(end_utc IS NULL OR end_utc > ?2)ORDER BY start_utc',
      variables: [Variable<int>(rangeEnd), Variable<int>(rangeStart)],
      readsFrom: {this.timeEntries},
    ).asyncMap(this.timeEntries.mapFromRow);
  }

  Selectable<TimeEntryRow> runningEntry() {
    return customSelect(
      'SELECT * FROM time_entries WHERE is_running = 1',
      variables: [],
      readsFrom: {this.timeEntries},
    ).asyncMap(this.timeEntries.mapFromRow);
  }

  Selectable<TimeEntryRow> lastFinishedEntry() {
    return customSelect(
      'SELECT * FROM time_entries WHERE deleted_at IS NULL AND end_utc IS NOT NULL ORDER BY end_utc DESC LIMIT 1',
      variables: [],
      readsFrom: {this.timeEntries},
    ).asyncMap(this.timeEntries.mapFromRow);
  }

  Selectable<TimeEntryRow> entryEndingAtOrBefore(
    String excludeId,
    int instant,
  ) {
    return customSelect(
      'SELECT * FROM time_entries WHERE deleted_at IS NULL AND id != ?1 AND start_utc < ?2 ORDER BY start_utc DESC LIMIT 1',
      variables: [Variable<String>(excludeId), Variable<int>(instant)],
      readsFrom: {this.timeEntries},
    ).asyncMap(this.timeEntries.mapFromRow);
  }

  Selectable<TimeEntryRow> entryStartingAfter(String excludeId, int instant) {
    return customSelect(
      'SELECT * FROM time_entries WHERE deleted_at IS NULL AND id != ?1 AND start_utc > ?2 ORDER BY start_utc ASC LIMIT 1',
      variables: [Variable<String>(excludeId), Variable<int>(instant)],
      readsFrom: {this.timeEntries},
    ).asyncMap(this.timeEntries.mapFromRow);
  }

  Selectable<ActivityUsageSinceResult> activityUsageSince(int since) {
    return customSelect(
      'SELECT"a"."id" AS "nested_0.id", "a"."name" AS "nested_0.name", "a"."name_key" AS "nested_0.name_key", "a"."color_seed" AS "nested_0.color_seed", "a"."archived" AS "nested_0.archived", "a"."created_at" AS "nested_0.created_at", "a"."updated_at" AS "nested_0.updated_at", e.start_utc AS used_at FROM activities AS a INNER JOIN time_entries AS e ON e.activity_id = a.id WHERE a.archived = 0 AND e.deleted_at IS NULL AND e.start_utc >= ?1',
      variables: [Variable<int>(since)],
      readsFrom: {this.timeEntries, this.activities},
    ).asyncMap(
      (QueryRow row) async => ActivityUsageSinceResult(
        a: await this.activities.mapFromRow(row, tablePrefix: 'nested_0'),
        usedAt: row.read<int>('used_at'),
      ),
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activities,
    timeEntries,
    uxEntriesSingleRunning,
    ixEntriesStart,
    ixEntriesActivityStart,
    settingsRow,
  ];
}

typedef $ActivitiesCreateCompanionBuilder = ActivitiesCompanion Function({
  required String id,
  required String name,
  required String nameKey,
  required int colorSeed,
  Value<int> archived,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $ActivitiesUpdateCompanionBuilder = ActivitiesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> nameKey,
  Value<int> colorSeed,
  Value<int> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

final class $ActivitiesReferences
    extends BaseReferences<_$AppDatabase, Activities, ActivityRow> {
  $ActivitiesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<TimeEntries, List<TimeEntryRow>>
  _timeEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timeEntries,
    aliasName: 'activities__id__time_entries__activity_id',
  );

  $TimeEntriesProcessedTableManager get timeEntriesRefs {
    final manager = $TimeEntriesTableManager(
      $_db,
      $_db.timeEntries,
    ).filter((f) => f.activityId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_timeEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ActivitiesFilterComposer extends Composer<_$AppDatabase, Activities> {
  $ActivitiesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorSeed => $composableBuilder(
    column: $table.colorSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> timeEntriesRefs(
    Expression<bool> Function($TimeEntriesFilterComposer f) f,
  ) {
    final $TimeEntriesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntries,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TimeEntriesFilterComposer(
            $db: $db,
            $table: $db.timeEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ActivitiesOrderingComposer extends Composer<_$AppDatabase, Activities> {
  $ActivitiesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorSeed => $composableBuilder(
    column: $table.colorSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ActivitiesAnnotationComposer
    extends Composer<_$AppDatabase, Activities> {
  $ActivitiesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<int> get colorSeed =>
      $composableBuilder(column: $table.colorSeed, builder: (column) => column);

  GeneratedColumn<int> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> timeEntriesRefs<T extends Object>(
    Expression<T> Function($TimeEntriesAnnotationComposer a) f,
  ) {
    final $TimeEntriesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeEntries,
      getReferencedColumn: (t) => t.activityId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $TimeEntriesAnnotationComposer(
            $db: $db,
            $table: $db.timeEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ActivitiesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Activities,
          ActivityRow,
          $ActivitiesFilterComposer,
          $ActivitiesOrderingComposer,
          $ActivitiesAnnotationComposer,
          $ActivitiesCreateCompanionBuilder,
          $ActivitiesUpdateCompanionBuilder,
          (ActivityRow, $ActivitiesReferences),
          ActivityRow,
          PrefetchHooks Function({bool timeEntriesRefs})
        > {
  $ActivitiesTableManager(_$AppDatabase db, Activities table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ActivitiesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ActivitiesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ActivitiesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<int> colorSeed = const Value.absent(),
                Value<int> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                name: name,
                nameKey: nameKey,
                colorSeed: colorSeed,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String nameKey,
                required int colorSeed,
                Value<int> archived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                name: name,
                nameKey: nameKey,
                colorSeed: colorSeed,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Activities, ActivityRow>(table),
                  $ActivitiesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({timeEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (timeEntriesRefs) db.timeEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (timeEntriesRefs)
                    await $_getPrefetchedData<
                      ActivityRow,
                      Activities,
                      TimeEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $ActivitiesReferences
                          ._timeEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $ActivitiesReferences(db, table, p0).timeEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.activityId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ActivitiesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Activities,
      ActivityRow,
      $ActivitiesFilterComposer,
      $ActivitiesOrderingComposer,
      $ActivitiesAnnotationComposer,
      $ActivitiesCreateCompanionBuilder,
      $ActivitiesUpdateCompanionBuilder,
      (ActivityRow, $ActivitiesReferences),
      ActivityRow,
      PrefetchHooks Function({bool timeEntriesRefs})
    >;
typedef $TimeEntriesCreateCompanionBuilder = TimeEntriesCompanion Function({
  required String id,
  required String activityId,
  Value<String?> note,
  required int startUtc,
  Value<int?> endUtc,
  required String tzName,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $TimeEntriesUpdateCompanionBuilder = TimeEntriesCompanion Function({
  Value<String> id,
  Value<String> activityId,
  Value<String?> note,
  Value<int> startUtc,
  Value<int?> endUtc,
  Value<String> tzName,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $TimeEntriesReferences
    extends BaseReferences<_$AppDatabase, TimeEntries, TimeEntryRow> {
  $TimeEntriesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Activities _activityIdTable(_$AppDatabase db) =>
      db.activities.createAlias('time_entries__activity_id__activities__id');

  $ActivitiesProcessedTableManager get activityId {
    final $_column = $_itemColumn<String>('activity_id')!;

    final manager = $ActivitiesTableManager(
      $_db,
      $_db.activities,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activityIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $TimeEntriesFilterComposer extends Composer<_$AppDatabase, TimeEntries> {
  $TimeEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tzName => $composableBuilder(
    column: $table.tzName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isRunning => $composableBuilder(
    column: $table.isRunning,
    builder: (column) => ColumnFilters(column),
  );

  $ActivitiesFilterComposer get activityId {
    final $ActivitiesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ActivitiesFilterComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TimeEntriesOrderingComposer
    extends Composer<_$AppDatabase, TimeEntries> {
  $TimeEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tzName => $composableBuilder(
    column: $table.tzName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isRunning => $composableBuilder(
    column: $table.isRunning,
    builder: (column) => ColumnOrderings(column),
  );

  $ActivitiesOrderingComposer get activityId {
    final $ActivitiesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ActivitiesOrderingComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TimeEntriesAnnotationComposer
    extends Composer<_$AppDatabase, TimeEntries> {
  $TimeEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<int> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<String> get tzName =>
      $composableBuilder(column: $table.tzName, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get isRunning =>
      $composableBuilder(column: $table.isRunning, builder: (column) => column);

  $ActivitiesAnnotationComposer get activityId {
    final $ActivitiesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activityId,
      referencedTable: $db.activities,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ActivitiesAnnotationComposer(
            $db: $db,
            $table: $db.activities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $TimeEntriesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          TimeEntries,
          TimeEntryRow,
          $TimeEntriesFilterComposer,
          $TimeEntriesOrderingComposer,
          $TimeEntriesAnnotationComposer,
          $TimeEntriesCreateCompanionBuilder,
          $TimeEntriesUpdateCompanionBuilder,
          (TimeEntryRow, $TimeEntriesReferences),
          TimeEntryRow,
          PrefetchHooks Function({bool activityId})
        > {
  $TimeEntriesTableManager(_$AppDatabase db, TimeEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TimeEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TimeEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TimeEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> startUtc = const Value.absent(),
                Value<int?> endUtc = const Value.absent(),
                Value<String> tzName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeEntriesCompanion(
                id: id,
                activityId: activityId,
                note: note,
                startUtc: startUtc,
                endUtc: endUtc,
                tzName: tzName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityId,
                Value<String?> note = const Value.absent(),
                required int startUtc,
                Value<int?> endUtc = const Value.absent(),
                required String tzName,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeEntriesCompanion.insert(
                id: id,
                activityId: activityId,
                note: note,
                startUtc: startUtc,
                endUtc: endUtc,
                tzName: tzName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<TimeEntries, TimeEntryRow>(table),
                  $TimeEntriesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityId = false}) {
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
                    if (activityId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.activityId,
                        referencedTable: $TimeEntriesReferences
                            ._activityIdTable(db),
                        referencedColumn: $TimeEntriesReferences
                            ._activityIdTable(db)
                            .id,
                      ) as T;
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

typedef $TimeEntriesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      TimeEntries,
      TimeEntryRow,
      $TimeEntriesFilterComposer,
      $TimeEntriesOrderingComposer,
      $TimeEntriesAnnotationComposer,
      $TimeEntriesCreateCompanionBuilder,
      $TimeEntriesUpdateCompanionBuilder,
      (TimeEntryRow, $TimeEntriesReferences),
      TimeEntryRow,
      PrefetchHooks Function({bool activityId})
    >;
typedef $SettingsRowCreateCompanionBuilder = SettingsRowCompanion Function({
  Value<int> id,
  Value<int> snapMinutes,
  Value<int> use24HourClock,
  Value<String> themeMode,
  Value<double> pixelsPerHour,
  Value<int> continueMinutes,
});
typedef $SettingsRowUpdateCompanionBuilder = SettingsRowCompanion Function({
  Value<int> id,
  Value<int> snapMinutes,
  Value<int> use24HourClock,
  Value<String> themeMode,
  Value<double> pixelsPerHour,
  Value<int> continueMinutes,
});

class $SettingsRowFilterComposer extends Composer<_$AppDatabase, SettingsRow> {
  $SettingsRowFilterComposer({
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

  ColumnFilters<int> get snapMinutes => $composableBuilder(
    column: $table.snapMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get use24HourClock => $composableBuilder(
    column: $table.use24HourClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pixelsPerHour => $composableBuilder(
    column: $table.pixelsPerHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get continueMinutes => $composableBuilder(
    column: $table.continueMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $SettingsRowOrderingComposer
    extends Composer<_$AppDatabase, SettingsRow> {
  $SettingsRowOrderingComposer({
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

  ColumnOrderings<int> get snapMinutes => $composableBuilder(
    column: $table.snapMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get use24HourClock => $composableBuilder(
    column: $table.use24HourClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pixelsPerHour => $composableBuilder(
    column: $table.pixelsPerHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get continueMinutes => $composableBuilder(
    column: $table.continueMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SettingsRowAnnotationComposer
    extends Composer<_$AppDatabase, SettingsRow> {
  $SettingsRowAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get snapMinutes => $composableBuilder(
    column: $table.snapMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get use24HourClock => $composableBuilder(
    column: $table.use24HourClock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<double> get pixelsPerHour => $composableBuilder(
    column: $table.pixelsPerHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get continueMinutes => $composableBuilder(
    column: $table.continueMinutes,
    builder: (column) => column,
  );
}

class $SettingsRowTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SettingsRow,
          SettingsRowData,
          $SettingsRowFilterComposer,
          $SettingsRowOrderingComposer,
          $SettingsRowAnnotationComposer,
          $SettingsRowCreateCompanionBuilder,
          $SettingsRowUpdateCompanionBuilder,
          (
            SettingsRowData,
            BaseReferences<_$AppDatabase, SettingsRow, SettingsRowData>,
          ),
          SettingsRowData,
          PrefetchHooks Function()
        > {
  $SettingsRowTableManager(_$AppDatabase db, SettingsRow table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SettingsRowFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SettingsRowOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SettingsRowAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snapMinutes = const Value.absent(),
                Value<int> use24HourClock = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<double> pixelsPerHour = const Value.absent(),
                Value<int> continueMinutes = const Value.absent(),
              }) => SettingsRowCompanion(
                id: id,
                snapMinutes: snapMinutes,
                use24HourClock: use24HourClock,
                themeMode: themeMode,
                pixelsPerHour: pixelsPerHour,
                continueMinutes: continueMinutes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snapMinutes = const Value.absent(),
                Value<int> use24HourClock = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<double> pixelsPerHour = const Value.absent(),
                Value<int> continueMinutes = const Value.absent(),
              }) => SettingsRowCompanion.insert(
                id: id,
                snapMinutes: snapMinutes,
                use24HourClock: use24HourClock,
                themeMode: themeMode,
                pixelsPerHour: pixelsPerHour,
                continueMinutes: continueMinutes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SettingsRow, SettingsRowData>(table),
                  BaseReferences<_$AppDatabase, SettingsRow, SettingsRowData>(
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

typedef $SettingsRowProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SettingsRow,
      SettingsRowData,
      $SettingsRowFilterComposer,
      $SettingsRowOrderingComposer,
      $SettingsRowAnnotationComposer,
      $SettingsRowCreateCompanionBuilder,
      $SettingsRowUpdateCompanionBuilder,
      (
        SettingsRowData,
        BaseReferences<_$AppDatabase, SettingsRow, SettingsRowData>,
      ),
      SettingsRowData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $ActivitiesTableManager get activities =>
      $ActivitiesTableManager(_db, _db.activities);
  $TimeEntriesTableManager get timeEntries =>
      $TimeEntriesTableManager(_db, _db.timeEntries);
  $SettingsRowTableManager get settingsRow =>
      $SettingsRowTableManager(_db, _db.settingsRow);
}

class ActivityUsageSinceResult {
  final ActivityRow a;
  final int usedAt;
  ActivityUsageSinceResult({required this.a, required this.usedAt});
}
