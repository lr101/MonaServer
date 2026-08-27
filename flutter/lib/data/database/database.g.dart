// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GroupEntitiesTable extends GroupEntities
    with TableInfo<$GroupEntitiesTable, GroupDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<int> visibility = GeneratedColumn<int>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIsMemberMeta = const VerificationMeta(
    'userIsMember',
  );
  @override
  late final GeneratedColumn<bool> userIsMember = GeneratedColumn<bool>(
    'user_is_member',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_is_member" IN (0, 1))',
    ),
  );
  static const VerificationMeta _inviteUrlMeta = const VerificationMeta(
    'inviteUrl',
  );
  @override
  late final GeneratedColumn<String> inviteUrl = GeneratedColumn<String>(
    'invite_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupAdminMeta = const VerificationMeta(
    'groupAdmin',
  );
  @override
  late final GeneratedColumn<String> groupAdmin = GeneratedColumn<String>(
    'group_admin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActivatedMeta = const VerificationMeta(
    'isActivated',
  );
  @override
  late final GeneratedColumn<bool> isActivated = GeneratedColumn<bool>(
    'is_activated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_activated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SeasonEntity?, String>
  bestSeason = GeneratedColumn<String>(
    'best_season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<SeasonEntity?>($GroupEntitiesTable.$converterbestSeasonn);
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    groupId,
    name,
    visibility,
    userIsMember,
    inviteUrl,
    groupAdmin,
    description,
    isActivated,
    lastUpdated,
    link,
    bestSeason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
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
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    } else if (isInserting) {
      context.missing(_visibilityMeta);
    }
    if (data.containsKey('user_is_member')) {
      context.handle(
        _userIsMemberMeta,
        userIsMember.isAcceptableOrUnknown(
          data['user_is_member']!,
          _userIsMemberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userIsMemberMeta);
    }
    if (data.containsKey('invite_url')) {
      context.handle(
        _inviteUrlMeta,
        inviteUrl.isAcceptableOrUnknown(data['invite_url']!, _inviteUrlMeta),
      );
    }
    if (data.containsKey('group_admin')) {
      context.handle(
        _groupAdminMeta,
        groupAdmin.isAcceptableOrUnknown(data['group_admin']!, _groupAdminMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_activated')) {
      context.handle(
        _isActivatedMeta,
        isActivated.isAcceptableOrUnknown(
          data['is_activated']!,
          _isActivatedMeta,
        ),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  GroupDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visibility'],
      )!,
      userIsMember: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_is_member'],
      )!,
      inviteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invite_url'],
      ),
      groupAdmin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_admin'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActivated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_activated'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      ),
      bestSeason: $GroupEntitiesTable.$converterbestSeasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}best_season'],
        ),
      ),
    );
  }

  @override
  $GroupEntitiesTable createAlias(String alias) {
    return $GroupEntitiesTable(attachedDatabase, alias);
  }

  static TypeConverter<SeasonEntity, String> $converterbestSeason =
      const SeasonConverter();
  static TypeConverter<SeasonEntity?, String?> $converterbestSeasonn =
      NullAwareTypeConverter.wrap($converterbestSeason);
}

class GroupDb extends DataClass implements Insertable<GroupDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String groupId;
  final String name;
  final int visibility;
  final bool userIsMember;
  final String? inviteUrl;
  final String? groupAdmin;
  final String? description;
  final bool isActivated;
  final DateTime? lastUpdated;
  final String? link;
  final SeasonEntity? bestSeason;
  const GroupDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.groupId,
    required this.name,
    required this.visibility,
    required this.userIsMember,
    this.inviteUrl,
    this.groupAdmin,
    this.description,
    required this.isActivated,
    this.lastUpdated,
    this.link,
    this.bestSeason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['visibility'] = Variable<int>(visibility);
    map['user_is_member'] = Variable<bool>(userIsMember);
    if (!nullToAbsent || inviteUrl != null) {
      map['invite_url'] = Variable<String>(inviteUrl);
    }
    if (!nullToAbsent || groupAdmin != null) {
      map['group_admin'] = Variable<String>(groupAdmin);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_activated'] = Variable<bool>(isActivated);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    if (!nullToAbsent || link != null) {
      map['link'] = Variable<String>(link);
    }
    if (!nullToAbsent || bestSeason != null) {
      map['best_season'] = Variable<String>(
        $GroupEntitiesTable.$converterbestSeasonn.toSql(bestSeason),
      );
    }
    return map;
  }

  GroupEntitiesCompanion toCompanion(bool nullToAbsent) {
    return GroupEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      groupId: Value(groupId),
      name: Value(name),
      visibility: Value(visibility),
      userIsMember: Value(userIsMember),
      inviteUrl: inviteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(inviteUrl),
      groupAdmin: groupAdmin == null && nullToAbsent
          ? const Value.absent()
          : Value(groupAdmin),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActivated: Value(isActivated),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
      link: link == null && nullToAbsent ? const Value.absent() : Value(link),
      bestSeason: bestSeason == null && nullToAbsent
          ? const Value.absent()
          : Value(bestSeason),
    );
  }

  factory GroupDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      visibility: serializer.fromJson<int>(json['visibility']),
      userIsMember: serializer.fromJson<bool>(json['userIsMember']),
      inviteUrl: serializer.fromJson<String?>(json['inviteUrl']),
      groupAdmin: serializer.fromJson<String?>(json['groupAdmin']),
      description: serializer.fromJson<String?>(json['description']),
      isActivated: serializer.fromJson<bool>(json['isActivated']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
      link: serializer.fromJson<String?>(json['link']),
      bestSeason: serializer.fromJson<SeasonEntity?>(json['bestSeason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'visibility': serializer.toJson<int>(visibility),
      'userIsMember': serializer.toJson<bool>(userIsMember),
      'inviteUrl': serializer.toJson<String?>(inviteUrl),
      'groupAdmin': serializer.toJson<String?>(groupAdmin),
      'description': serializer.toJson<String?>(description),
      'isActivated': serializer.toJson<bool>(isActivated),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
      'link': serializer.toJson<String?>(link),
      'bestSeason': serializer.toJson<SeasonEntity?>(bestSeason),
    };
  }

  GroupDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? groupId,
    String? name,
    int? visibility,
    bool? userIsMember,
    Value<String?> inviteUrl = const Value.absent(),
    Value<String?> groupAdmin = const Value.absent(),
    Value<String?> description = const Value.absent(),
    bool? isActivated,
    Value<DateTime?> lastUpdated = const Value.absent(),
    Value<String?> link = const Value.absent(),
    Value<SeasonEntity?> bestSeason = const Value.absent(),
  }) => GroupDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    visibility: visibility ?? this.visibility,
    userIsMember: userIsMember ?? this.userIsMember,
    inviteUrl: inviteUrl.present ? inviteUrl.value : this.inviteUrl,
    groupAdmin: groupAdmin.present ? groupAdmin.value : this.groupAdmin,
    description: description.present ? description.value : this.description,
    isActivated: isActivated ?? this.isActivated,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
    link: link.present ? link.value : this.link,
    bestSeason: bestSeason.present ? bestSeason.value : this.bestSeason,
  );
  GroupDb copyWithCompanion(GroupEntitiesCompanion data) {
    return GroupDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      userIsMember: data.userIsMember.present
          ? data.userIsMember.value
          : this.userIsMember,
      inviteUrl: data.inviteUrl.present ? data.inviteUrl.value : this.inviteUrl,
      groupAdmin: data.groupAdmin.present
          ? data.groupAdmin.value
          : this.groupAdmin,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActivated: data.isActivated.present
          ? data.isActivated.value
          : this.isActivated,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      link: data.link.present ? data.link.value : this.link,
      bestSeason: data.bestSeason.present
          ? data.bestSeason.value
          : this.bestSeason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('visibility: $visibility, ')
          ..write('userIsMember: $userIsMember, ')
          ..write('inviteUrl: $inviteUrl, ')
          ..write('groupAdmin: $groupAdmin, ')
          ..write('description: $description, ')
          ..write('isActivated: $isActivated, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('link: $link, ')
          ..write('bestSeason: $bestSeason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    groupId,
    name,
    visibility,
    userIsMember,
    inviteUrl,
    groupAdmin,
    description,
    isActivated,
    lastUpdated,
    link,
    bestSeason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.visibility == this.visibility &&
          other.userIsMember == this.userIsMember &&
          other.inviteUrl == this.inviteUrl &&
          other.groupAdmin == this.groupAdmin &&
          other.description == this.description &&
          other.isActivated == this.isActivated &&
          other.lastUpdated == this.lastUpdated &&
          other.link == this.link &&
          other.bestSeason == this.bestSeason);
}

class GroupEntitiesCompanion extends UpdateCompanion<GroupDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> groupId;
  final Value<String> name;
  final Value<int> visibility;
  final Value<bool> userIsMember;
  final Value<String?> inviteUrl;
  final Value<String?> groupAdmin;
  final Value<String?> description;
  final Value<bool> isActivated;
  final Value<DateTime?> lastUpdated;
  final Value<String?> link;
  final Value<SeasonEntity?> bestSeason;
  const GroupEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.visibility = const Value.absent(),
    this.userIsMember = const Value.absent(),
    this.inviteUrl = const Value.absent(),
    this.groupAdmin = const Value.absent(),
    this.description = const Value.absent(),
    this.isActivated = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.link = const Value.absent(),
    this.bestSeason = const Value.absent(),
  });
  GroupEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String groupId,
    required String name,
    required int visibility,
    required bool userIsMember,
    this.inviteUrl = const Value.absent(),
    this.groupAdmin = const Value.absent(),
    this.description = const Value.absent(),
    this.isActivated = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.link = const Value.absent(),
    this.bestSeason = const Value.absent(),
  }) : ttl = Value(ttl),
       groupId = Value(groupId),
       name = Value(name),
       visibility = Value(visibility),
       userIsMember = Value(userIsMember);
  static Insertable<GroupDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<int>? visibility,
    Expression<bool>? userIsMember,
    Expression<String>? inviteUrl,
    Expression<String>? groupAdmin,
    Expression<String>? description,
    Expression<bool>? isActivated,
    Expression<DateTime>? lastUpdated,
    Expression<String>? link,
    Expression<String>? bestSeason,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (visibility != null) 'visibility': visibility,
      if (userIsMember != null) 'user_is_member': userIsMember,
      if (inviteUrl != null) 'invite_url': inviteUrl,
      if (groupAdmin != null) 'group_admin': groupAdmin,
      if (description != null) 'description': description,
      if (isActivated != null) 'is_activated': isActivated,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (link != null) 'link': link,
      if (bestSeason != null) 'best_season': bestSeason,
    });
  }

  GroupEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? groupId,
    Value<String>? name,
    Value<int>? visibility,
    Value<bool>? userIsMember,
    Value<String?>? inviteUrl,
    Value<String?>? groupAdmin,
    Value<String?>? description,
    Value<bool>? isActivated,
    Value<DateTime?>? lastUpdated,
    Value<String?>? link,
    Value<SeasonEntity?>? bestSeason,
  }) {
    return GroupEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      visibility: visibility ?? this.visibility,
      userIsMember: userIsMember ?? this.userIsMember,
      inviteUrl: inviteUrl ?? this.inviteUrl,
      groupAdmin: groupAdmin ?? this.groupAdmin,
      description: description ?? this.description,
      isActivated: isActivated ?? this.isActivated,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      link: link ?? this.link,
      bestSeason: bestSeason ?? this.bestSeason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<int>(visibility.value);
    }
    if (userIsMember.present) {
      map['user_is_member'] = Variable<bool>(userIsMember.value);
    }
    if (inviteUrl.present) {
      map['invite_url'] = Variable<String>(inviteUrl.value);
    }
    if (groupAdmin.present) {
      map['group_admin'] = Variable<String>(groupAdmin.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActivated.present) {
      map['is_activated'] = Variable<bool>(isActivated.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (bestSeason.present) {
      map['best_season'] = Variable<String>(
        $GroupEntitiesTable.$converterbestSeasonn.toSql(bestSeason.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('visibility: $visibility, ')
          ..write('userIsMember: $userIsMember, ')
          ..write('inviteUrl: $inviteUrl, ')
          ..write('groupAdmin: $groupAdmin, ')
          ..write('description: $description, ')
          ..write('isActivated: $isActivated, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('link: $link, ')
          ..write('bestSeason: $bestSeason')
          ..write(')'))
        .toString();
  }
}

class $ImageEntitiesTable extends ImageEntities
    with TableInfo<$ImageEntitiesTable, ImageDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImageType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ImageType>($ImageEntitiesTable.$convertertype);
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<Uint8List> image = GeneratedColumn<Uint8List>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    id,
    type,
    image,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  ImageDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $ImageEntitiesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}image'],
      ),
    );
  }

  @override
  $ImageEntitiesTable createAlias(String alias) {
    return $ImageEntitiesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImageType, int, int> $convertertype =
      const EnumIndexConverter<ImageType>(ImageType.values);
}

class ImageDb extends DataClass implements Insertable<ImageDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String id;
  final ImageType type;
  final Uint8List? image;
  const ImageDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.id,
    required this.type,
    this.image,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<int>(
        $ImageEntitiesTable.$convertertype.toSql(type),
      );
    }
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<Uint8List>(image);
    }
    return map;
  }

  ImageEntitiesCompanion toCompanion(bool nullToAbsent) {
    return ImageEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      id: Value(id),
      type: Value(type),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
    );
  }

  factory ImageDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      id: serializer.fromJson<String>(json['id']),
      type: $ImageEntitiesTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      image: serializer.fromJson<Uint8List?>(json['image']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<int>(
        $ImageEntitiesTable.$convertertype.toJson(type),
      ),
      'image': serializer.toJson<Uint8List?>(image),
    };
  }

  ImageDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? id,
    ImageType? type,
    Value<Uint8List?> image = const Value.absent(),
  }) => ImageDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    id: id ?? this.id,
    type: type ?? this.type,
    image: image.present ? image.value : this.image,
  );
  ImageDb copyWithCompanion(ImageEntitiesCompanion data) {
    return ImageDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      image: data.image.present ? data.image.value : this.image,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('image: $image')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    id,
    type,
    $driftBlobEquality.hash(image),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.id == this.id &&
          other.type == this.type &&
          $driftBlobEquality.equals(other.image, this.image));
}

class ImageEntitiesCompanion extends UpdateCompanion<ImageDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> id;
  final Value<ImageType> type;
  final Value<Uint8List?> image;
  const ImageEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.image = const Value.absent(),
  });
  ImageEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String id,
    required ImageType type,
    this.image = const Value.absent(),
  }) : ttl = Value(ttl),
       id = Value(id),
       type = Value(type);
  static Insertable<ImageDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? id,
    Expression<int>? type,
    Expression<Uint8List>? image,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (image != null) 'image': image,
    });
  }

  ImageEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? id,
    Value<ImageType>? type,
    Value<Uint8List?>? image,
  }) {
    return ImageEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      id: id ?? this.id,
      type: type ?? this.type,
      image: image ?? this.image,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $ImageEntitiesTable.$convertertype.toSql(type.value),
      );
    }
    if (image.present) {
      map['image'] = Variable<Uint8List>(image.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('image: $image')
          ..write(')'))
        .toString();
  }
}

class $MemberEntitiesTable extends MemberEntities
    with TableInfo<$MemberEntitiesTable, MemberDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemberEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<
    List<Map<String, dynamic>>,
    String
  >
  members =
      GeneratedColumn<String>(
        'members',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<Map<String, dynamic>>>(
        $MemberEntitiesTable.$convertermembers,
      );
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    groupId,
    members,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'member_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemberDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  MemberDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemberDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      members: $MemberEntitiesTable.$convertermembers.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}members'],
        )!,
      ),
    );
  }

  @override
  $MemberEntitiesTable createAlias(String alias) {
    return $MemberEntitiesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<Map<String, dynamic>>, String> $convertermembers =
      const MembersConverter();
}

class MemberDb extends DataClass implements Insertable<MemberDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String groupId;
  final List<Map<String, dynamic>> members;
  const MemberDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.groupId,
    required this.members,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['group_id'] = Variable<String>(groupId);
    {
      map['members'] = Variable<String>(
        $MemberEntitiesTable.$convertermembers.toSql(members),
      );
    }
    return map;
  }

  MemberEntitiesCompanion toCompanion(bool nullToAbsent) {
    return MemberEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      groupId: Value(groupId),
      members: Value(members),
    );
  }

  factory MemberDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemberDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      groupId: serializer.fromJson<String>(json['groupId']),
      members: serializer.fromJson<List<Map<String, dynamic>>>(json['members']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'groupId': serializer.toJson<String>(groupId),
      'members': serializer.toJson<List<Map<String, dynamic>>>(members),
    };
  }

  MemberDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? groupId,
    List<Map<String, dynamic>>? members,
  }) => MemberDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    groupId: groupId ?? this.groupId,
    members: members ?? this.members,
  );
  MemberDb copyWithCompanion(MemberEntitiesCompanion data) {
    return MemberDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      members: data.members.present ? data.members.value : this.members,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemberDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('groupId: $groupId, ')
          ..write('members: $members')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(isarId, ttl, hits, keepAlive, onlySession, groupId, members);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.groupId == this.groupId &&
          other.members == this.members);
}

class MemberEntitiesCompanion extends UpdateCompanion<MemberDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> groupId;
  final Value<List<Map<String, dynamic>>> members;
  const MemberEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.groupId = const Value.absent(),
    this.members = const Value.absent(),
  });
  MemberEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String groupId,
    required List<Map<String, dynamic>> members,
  }) : ttl = Value(ttl),
       groupId = Value(groupId),
       members = Value(members);
  static Insertable<MemberDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? groupId,
    Expression<String>? members,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (groupId != null) 'group_id': groupId,
      if (members != null) 'members': members,
    });
  }

  MemberEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? groupId,
    Value<List<Map<String, dynamic>>>? members,
  }) {
    return MemberEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      groupId: groupId ?? this.groupId,
      members: members ?? this.members,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (members.present) {
      map['members'] = Variable<String>(
        $MemberEntitiesTable.$convertermembers.toSql(members.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemberEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('groupId: $groupId, ')
          ..write('members: $members')
          ..write(')'))
        .toString();
  }
}

class $PinEntitiesTable extends PinEntities
    with TableInfo<$PinEntitiesTable, PinDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinIdMeta = const VerificationMeta('pinId');
  @override
  late final GeneratedColumn<String> pinId = GeneratedColumn<String>(
    'pin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creationDateMeta = const VerificationMeta(
    'creationDate',
  );
  @override
  late final GeneratedColumn<DateTime> creationDate = GeneratedColumn<DateTime>(
    'creation_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatorMeta = const VerificationMeta(
    'creator',
  );
  @override
  late final GeneratedColumn<String> creator = GeneratedColumn<String>(
    'creator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSyncedMeta = const VerificationMeta(
    'lastSynced',
  );
  @override
  late final GeneratedColumn<DateTime> lastSynced = GeneratedColumn<DateTime>(
    'last_synced',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    pinId,
    latitude,
    longitude,
    creationDate,
    description,
    creator,
    groupId,
    isHidden,
    lastSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pin_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<PinDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('pin_id')) {
      context.handle(
        _pinIdMeta,
        pinId.isAcceptableOrUnknown(data['pin_id']!, _pinIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pinIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('creation_date')) {
      context.handle(
        _creationDateMeta,
        creationDate.isAcceptableOrUnknown(
          data['creation_date']!,
          _creationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creationDateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('creator')) {
      context.handle(
        _creatorMeta,
        creator.isAcceptableOrUnknown(data['creator']!, _creatorMeta),
      );
    } else if (isInserting) {
      context.missing(_creatorMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('last_synced')) {
      context.handle(
        _lastSyncedMeta,
        lastSynced.isAcceptableOrUnknown(data['last_synced']!, _lastSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  PinDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      pinId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      creationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creation_date'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      creator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      lastSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced'],
      ),
    );
  }

  @override
  $PinEntitiesTable createAlias(String alias) {
    return $PinEntitiesTable(attachedDatabase, alias);
  }
}

class PinDb extends DataClass implements Insertable<PinDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String pinId;
  final double latitude;
  final double longitude;
  final DateTime creationDate;
  final String? description;
  final String creator;
  final String groupId;
  final bool isHidden;
  final DateTime? lastSynced;
  const PinDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.pinId,
    required this.latitude,
    required this.longitude,
    required this.creationDate,
    this.description,
    required this.creator,
    required this.groupId,
    required this.isHidden,
    this.lastSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['pin_id'] = Variable<String>(pinId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['creation_date'] = Variable<DateTime>(creationDate);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['creator'] = Variable<String>(creator);
    map['group_id'] = Variable<String>(groupId);
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || lastSynced != null) {
      map['last_synced'] = Variable<DateTime>(lastSynced);
    }
    return map;
  }

  PinEntitiesCompanion toCompanion(bool nullToAbsent) {
    return PinEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      pinId: Value(pinId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      creationDate: Value(creationDate),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      creator: Value(creator),
      groupId: Value(groupId),
      isHidden: Value(isHidden),
      lastSynced: lastSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSynced),
    );
  }

  factory PinDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      pinId: serializer.fromJson<String>(json['pinId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      creationDate: serializer.fromJson<DateTime>(json['creationDate']),
      description: serializer.fromJson<String?>(json['description']),
      creator: serializer.fromJson<String>(json['creator']),
      groupId: serializer.fromJson<String>(json['groupId']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      lastSynced: serializer.fromJson<DateTime?>(json['lastSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'pinId': serializer.toJson<String>(pinId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'creationDate': serializer.toJson<DateTime>(creationDate),
      'description': serializer.toJson<String?>(description),
      'creator': serializer.toJson<String>(creator),
      'groupId': serializer.toJson<String>(groupId),
      'isHidden': serializer.toJson<bool>(isHidden),
      'lastSynced': serializer.toJson<DateTime?>(lastSynced),
    };
  }

  PinDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? pinId,
    double? latitude,
    double? longitude,
    DateTime? creationDate,
    Value<String?> description = const Value.absent(),
    String? creator,
    String? groupId,
    bool? isHidden,
    Value<DateTime?> lastSynced = const Value.absent(),
  }) => PinDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    pinId: pinId ?? this.pinId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    creationDate: creationDate ?? this.creationDate,
    description: description.present ? description.value : this.description,
    creator: creator ?? this.creator,
    groupId: groupId ?? this.groupId,
    isHidden: isHidden ?? this.isHidden,
    lastSynced: lastSynced.present ? lastSynced.value : this.lastSynced,
  );
  PinDb copyWithCompanion(PinEntitiesCompanion data) {
    return PinDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      pinId: data.pinId.present ? data.pinId.value : this.pinId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      creationDate: data.creationDate.present
          ? data.creationDate.value
          : this.creationDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      creator: data.creator.present ? data.creator.value : this.creator,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      lastSynced: data.lastSynced.present
          ? data.lastSynced.value
          : this.lastSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('pinId: $pinId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('creationDate: $creationDate, ')
          ..write('description: $description, ')
          ..write('creator: $creator, ')
          ..write('groupId: $groupId, ')
          ..write('isHidden: $isHidden, ')
          ..write('lastSynced: $lastSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    pinId,
    latitude,
    longitude,
    creationDate,
    description,
    creator,
    groupId,
    isHidden,
    lastSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.pinId == this.pinId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.creationDate == this.creationDate &&
          other.description == this.description &&
          other.creator == this.creator &&
          other.groupId == this.groupId &&
          other.isHidden == this.isHidden &&
          other.lastSynced == this.lastSynced);
}

class PinEntitiesCompanion extends UpdateCompanion<PinDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> pinId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime> creationDate;
  final Value<String?> description;
  final Value<String> creator;
  final Value<String> groupId;
  final Value<bool> isHidden;
  final Value<DateTime?> lastSynced;
  const PinEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.pinId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.creationDate = const Value.absent(),
    this.description = const Value.absent(),
    this.creator = const Value.absent(),
    this.groupId = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.lastSynced = const Value.absent(),
  });
  PinEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String pinId,
    required double latitude,
    required double longitude,
    required DateTime creationDate,
    this.description = const Value.absent(),
    required String creator,
    required String groupId,
    this.isHidden = const Value.absent(),
    this.lastSynced = const Value.absent(),
  }) : ttl = Value(ttl),
       pinId = Value(pinId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       creationDate = Value(creationDate),
       creator = Value(creator),
       groupId = Value(groupId);
  static Insertable<PinDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? pinId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? creationDate,
    Expression<String>? description,
    Expression<String>? creator,
    Expression<String>? groupId,
    Expression<bool>? isHidden,
    Expression<DateTime>? lastSynced,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (pinId != null) 'pin_id': pinId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (creationDate != null) 'creation_date': creationDate,
      if (description != null) 'description': description,
      if (creator != null) 'creator': creator,
      if (groupId != null) 'group_id': groupId,
      if (isHidden != null) 'is_hidden': isHidden,
      if (lastSynced != null) 'last_synced': lastSynced,
    });
  }

  PinEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? pinId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<DateTime>? creationDate,
    Value<String?>? description,
    Value<String>? creator,
    Value<String>? groupId,
    Value<bool>? isHidden,
    Value<DateTime?>? lastSynced,
  }) {
    return PinEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      pinId: pinId ?? this.pinId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      creationDate: creationDate ?? this.creationDate,
      description: description ?? this.description,
      creator: creator ?? this.creator,
      groupId: groupId ?? this.groupId,
      isHidden: isHidden ?? this.isHidden,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (pinId.present) {
      map['pin_id'] = Variable<String>(pinId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (creationDate.present) {
      map['creation_date'] = Variable<DateTime>(creationDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (creator.present) {
      map['creator'] = Variable<String>(creator.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (lastSynced.present) {
      map['last_synced'] = Variable<DateTime>(lastSynced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('pinId: $pinId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('creationDate: $creationDate, ')
          ..write('description: $description, ')
          ..write('creator: $creator, ')
          ..write('groupId: $groupId, ')
          ..write('isHidden: $isHidden, ')
          ..write('lastSynced: $lastSynced')
          ..write(')'))
        .toString();
  }
}

class $PinLikeEntitiesTable extends PinLikeEntities
    with TableInfo<$PinLikeEntitiesTable, PinLikeDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinLikeEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeCountMeta = const VerificationMeta(
    'likeCount',
  );
  @override
  late final GeneratedColumn<int> likeCount = GeneratedColumn<int>(
    'like_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likePhotographyCountMeta =
      const VerificationMeta('likePhotographyCount');
  @override
  late final GeneratedColumn<int> likePhotographyCount = GeneratedColumn<int>(
    'like_photography_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeLocationCountMeta = const VerificationMeta(
    'likeLocationCount',
  );
  @override
  late final GeneratedColumn<int> likeLocationCount = GeneratedColumn<int>(
    'like_location_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeArtCountMeta = const VerificationMeta(
    'likeArtCount',
  );
  @override
  late final GeneratedColumn<int> likeArtCount = GeneratedColumn<int>(
    'like_art_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasLikeMeta = const VerificationMeta(
    'hasLike',
  );
  @override
  late final GeneratedColumn<bool> hasLike = GeneratedColumn<bool>(
    'has_like',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_like" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hasLikePhotographyMeta =
      const VerificationMeta('hasLikePhotography');
  @override
  late final GeneratedColumn<bool> hasLikePhotography = GeneratedColumn<bool>(
    'has_like_photography',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_like_photography" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hasLikeLocationMeta = const VerificationMeta(
    'hasLikeLocation',
  );
  @override
  late final GeneratedColumn<bool> hasLikeLocation = GeneratedColumn<bool>(
    'has_like_location',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_like_location" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hasLikeArtMeta = const VerificationMeta(
    'hasLikeArt',
  );
  @override
  late final GeneratedColumn<bool> hasLikeArt = GeneratedColumn<bool>(
    'has_like_art',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_like_art" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    id,
    likeCount,
    likePhotographyCount,
    likeLocationCount,
    likeArtCount,
    hasLike,
    hasLikePhotography,
    hasLikeLocation,
    hasLikeArt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pin_like_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<PinLikeDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('like_count')) {
      context.handle(
        _likeCountMeta,
        likeCount.isAcceptableOrUnknown(data['like_count']!, _likeCountMeta),
      );
    } else if (isInserting) {
      context.missing(_likeCountMeta);
    }
    if (data.containsKey('like_photography_count')) {
      context.handle(
        _likePhotographyCountMeta,
        likePhotographyCount.isAcceptableOrUnknown(
          data['like_photography_count']!,
          _likePhotographyCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likePhotographyCountMeta);
    }
    if (data.containsKey('like_location_count')) {
      context.handle(
        _likeLocationCountMeta,
        likeLocationCount.isAcceptableOrUnknown(
          data['like_location_count']!,
          _likeLocationCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likeLocationCountMeta);
    }
    if (data.containsKey('like_art_count')) {
      context.handle(
        _likeArtCountMeta,
        likeArtCount.isAcceptableOrUnknown(
          data['like_art_count']!,
          _likeArtCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likeArtCountMeta);
    }
    if (data.containsKey('has_like')) {
      context.handle(
        _hasLikeMeta,
        hasLike.isAcceptableOrUnknown(data['has_like']!, _hasLikeMeta),
      );
    } else if (isInserting) {
      context.missing(_hasLikeMeta);
    }
    if (data.containsKey('has_like_photography')) {
      context.handle(
        _hasLikePhotographyMeta,
        hasLikePhotography.isAcceptableOrUnknown(
          data['has_like_photography']!,
          _hasLikePhotographyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasLikePhotographyMeta);
    }
    if (data.containsKey('has_like_location')) {
      context.handle(
        _hasLikeLocationMeta,
        hasLikeLocation.isAcceptableOrUnknown(
          data['has_like_location']!,
          _hasLikeLocationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasLikeLocationMeta);
    }
    if (data.containsKey('has_like_art')) {
      context.handle(
        _hasLikeArtMeta,
        hasLikeArt.isAcceptableOrUnknown(
          data['has_like_art']!,
          _hasLikeArtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasLikeArtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  PinLikeDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinLikeDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      likeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_count'],
      )!,
      likePhotographyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_photography_count'],
      )!,
      likeLocationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_location_count'],
      )!,
      likeArtCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_art_count'],
      )!,
      hasLike: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_like'],
      )!,
      hasLikePhotography: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_like_photography'],
      )!,
      hasLikeLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_like_location'],
      )!,
      hasLikeArt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_like_art'],
      )!,
    );
  }

  @override
  $PinLikeEntitiesTable createAlias(String alias) {
    return $PinLikeEntitiesTable(attachedDatabase, alias);
  }
}

class PinLikeDb extends DataClass implements Insertable<PinLikeDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String id;
  final int likeCount;
  final int likePhotographyCount;
  final int likeLocationCount;
  final int likeArtCount;
  final bool hasLike;
  final bool hasLikePhotography;
  final bool hasLikeLocation;
  final bool hasLikeArt;
  const PinLikeDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.id,
    required this.likeCount,
    required this.likePhotographyCount,
    required this.likeLocationCount,
    required this.likeArtCount,
    required this.hasLike,
    required this.hasLikePhotography,
    required this.hasLikeLocation,
    required this.hasLikeArt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['id'] = Variable<String>(id);
    map['like_count'] = Variable<int>(likeCount);
    map['like_photography_count'] = Variable<int>(likePhotographyCount);
    map['like_location_count'] = Variable<int>(likeLocationCount);
    map['like_art_count'] = Variable<int>(likeArtCount);
    map['has_like'] = Variable<bool>(hasLike);
    map['has_like_photography'] = Variable<bool>(hasLikePhotography);
    map['has_like_location'] = Variable<bool>(hasLikeLocation);
    map['has_like_art'] = Variable<bool>(hasLikeArt);
    return map;
  }

  PinLikeEntitiesCompanion toCompanion(bool nullToAbsent) {
    return PinLikeEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      id: Value(id),
      likeCount: Value(likeCount),
      likePhotographyCount: Value(likePhotographyCount),
      likeLocationCount: Value(likeLocationCount),
      likeArtCount: Value(likeArtCount),
      hasLike: Value(hasLike),
      hasLikePhotography: Value(hasLikePhotography),
      hasLikeLocation: Value(hasLikeLocation),
      hasLikeArt: Value(hasLikeArt),
    );
  }

  factory PinLikeDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinLikeDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      id: serializer.fromJson<String>(json['id']),
      likeCount: serializer.fromJson<int>(json['likeCount']),
      likePhotographyCount: serializer.fromJson<int>(
        json['likePhotographyCount'],
      ),
      likeLocationCount: serializer.fromJson<int>(json['likeLocationCount']),
      likeArtCount: serializer.fromJson<int>(json['likeArtCount']),
      hasLike: serializer.fromJson<bool>(json['hasLike']),
      hasLikePhotography: serializer.fromJson<bool>(json['hasLikePhotography']),
      hasLikeLocation: serializer.fromJson<bool>(json['hasLikeLocation']),
      hasLikeArt: serializer.fromJson<bool>(json['hasLikeArt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'id': serializer.toJson<String>(id),
      'likeCount': serializer.toJson<int>(likeCount),
      'likePhotographyCount': serializer.toJson<int>(likePhotographyCount),
      'likeLocationCount': serializer.toJson<int>(likeLocationCount),
      'likeArtCount': serializer.toJson<int>(likeArtCount),
      'hasLike': serializer.toJson<bool>(hasLike),
      'hasLikePhotography': serializer.toJson<bool>(hasLikePhotography),
      'hasLikeLocation': serializer.toJson<bool>(hasLikeLocation),
      'hasLikeArt': serializer.toJson<bool>(hasLikeArt),
    };
  }

  PinLikeDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? id,
    int? likeCount,
    int? likePhotographyCount,
    int? likeLocationCount,
    int? likeArtCount,
    bool? hasLike,
    bool? hasLikePhotography,
    bool? hasLikeLocation,
    bool? hasLikeArt,
  }) => PinLikeDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    id: id ?? this.id,
    likeCount: likeCount ?? this.likeCount,
    likePhotographyCount: likePhotographyCount ?? this.likePhotographyCount,
    likeLocationCount: likeLocationCount ?? this.likeLocationCount,
    likeArtCount: likeArtCount ?? this.likeArtCount,
    hasLike: hasLike ?? this.hasLike,
    hasLikePhotography: hasLikePhotography ?? this.hasLikePhotography,
    hasLikeLocation: hasLikeLocation ?? this.hasLikeLocation,
    hasLikeArt: hasLikeArt ?? this.hasLikeArt,
  );
  PinLikeDb copyWithCompanion(PinLikeEntitiesCompanion data) {
    return PinLikeDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      id: data.id.present ? data.id.value : this.id,
      likeCount: data.likeCount.present ? data.likeCount.value : this.likeCount,
      likePhotographyCount: data.likePhotographyCount.present
          ? data.likePhotographyCount.value
          : this.likePhotographyCount,
      likeLocationCount: data.likeLocationCount.present
          ? data.likeLocationCount.value
          : this.likeLocationCount,
      likeArtCount: data.likeArtCount.present
          ? data.likeArtCount.value
          : this.likeArtCount,
      hasLike: data.hasLike.present ? data.hasLike.value : this.hasLike,
      hasLikePhotography: data.hasLikePhotography.present
          ? data.hasLikePhotography.value
          : this.hasLikePhotography,
      hasLikeLocation: data.hasLikeLocation.present
          ? data.hasLikeLocation.value
          : this.hasLikeLocation,
      hasLikeArt: data.hasLikeArt.present
          ? data.hasLikeArt.value
          : this.hasLikeArt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinLikeDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('id: $id, ')
          ..write('likeCount: $likeCount, ')
          ..write('likePhotographyCount: $likePhotographyCount, ')
          ..write('likeLocationCount: $likeLocationCount, ')
          ..write('likeArtCount: $likeArtCount, ')
          ..write('hasLike: $hasLike, ')
          ..write('hasLikePhotography: $hasLikePhotography, ')
          ..write('hasLikeLocation: $hasLikeLocation, ')
          ..write('hasLikeArt: $hasLikeArt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    id,
    likeCount,
    likePhotographyCount,
    likeLocationCount,
    likeArtCount,
    hasLike,
    hasLikePhotography,
    hasLikeLocation,
    hasLikeArt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinLikeDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.id == this.id &&
          other.likeCount == this.likeCount &&
          other.likePhotographyCount == this.likePhotographyCount &&
          other.likeLocationCount == this.likeLocationCount &&
          other.likeArtCount == this.likeArtCount &&
          other.hasLike == this.hasLike &&
          other.hasLikePhotography == this.hasLikePhotography &&
          other.hasLikeLocation == this.hasLikeLocation &&
          other.hasLikeArt == this.hasLikeArt);
}

class PinLikeEntitiesCompanion extends UpdateCompanion<PinLikeDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> id;
  final Value<int> likeCount;
  final Value<int> likePhotographyCount;
  final Value<int> likeLocationCount;
  final Value<int> likeArtCount;
  final Value<bool> hasLike;
  final Value<bool> hasLikePhotography;
  final Value<bool> hasLikeLocation;
  final Value<bool> hasLikeArt;
  const PinLikeEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.id = const Value.absent(),
    this.likeCount = const Value.absent(),
    this.likePhotographyCount = const Value.absent(),
    this.likeLocationCount = const Value.absent(),
    this.likeArtCount = const Value.absent(),
    this.hasLike = const Value.absent(),
    this.hasLikePhotography = const Value.absent(),
    this.hasLikeLocation = const Value.absent(),
    this.hasLikeArt = const Value.absent(),
  });
  PinLikeEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String id,
    required int likeCount,
    required int likePhotographyCount,
    required int likeLocationCount,
    required int likeArtCount,
    required bool hasLike,
    required bool hasLikePhotography,
    required bool hasLikeLocation,
    required bool hasLikeArt,
  }) : ttl = Value(ttl),
       id = Value(id),
       likeCount = Value(likeCount),
       likePhotographyCount = Value(likePhotographyCount),
       likeLocationCount = Value(likeLocationCount),
       likeArtCount = Value(likeArtCount),
       hasLike = Value(hasLike),
       hasLikePhotography = Value(hasLikePhotography),
       hasLikeLocation = Value(hasLikeLocation),
       hasLikeArt = Value(hasLikeArt);
  static Insertable<PinLikeDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? id,
    Expression<int>? likeCount,
    Expression<int>? likePhotographyCount,
    Expression<int>? likeLocationCount,
    Expression<int>? likeArtCount,
    Expression<bool>? hasLike,
    Expression<bool>? hasLikePhotography,
    Expression<bool>? hasLikeLocation,
    Expression<bool>? hasLikeArt,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (id != null) 'id': id,
      if (likeCount != null) 'like_count': likeCount,
      if (likePhotographyCount != null)
        'like_photography_count': likePhotographyCount,
      if (likeLocationCount != null) 'like_location_count': likeLocationCount,
      if (likeArtCount != null) 'like_art_count': likeArtCount,
      if (hasLike != null) 'has_like': hasLike,
      if (hasLikePhotography != null)
        'has_like_photography': hasLikePhotography,
      if (hasLikeLocation != null) 'has_like_location': hasLikeLocation,
      if (hasLikeArt != null) 'has_like_art': hasLikeArt,
    });
  }

  PinLikeEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? id,
    Value<int>? likeCount,
    Value<int>? likePhotographyCount,
    Value<int>? likeLocationCount,
    Value<int>? likeArtCount,
    Value<bool>? hasLike,
    Value<bool>? hasLikePhotography,
    Value<bool>? hasLikeLocation,
    Value<bool>? hasLikeArt,
  }) {
    return PinLikeEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      id: id ?? this.id,
      likeCount: likeCount ?? this.likeCount,
      likePhotographyCount: likePhotographyCount ?? this.likePhotographyCount,
      likeLocationCount: likeLocationCount ?? this.likeLocationCount,
      likeArtCount: likeArtCount ?? this.likeArtCount,
      hasLike: hasLike ?? this.hasLike,
      hasLikePhotography: hasLikePhotography ?? this.hasLikePhotography,
      hasLikeLocation: hasLikeLocation ?? this.hasLikeLocation,
      hasLikeArt: hasLikeArt ?? this.hasLikeArt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (likeCount.present) {
      map['like_count'] = Variable<int>(likeCount.value);
    }
    if (likePhotographyCount.present) {
      map['like_photography_count'] = Variable<int>(likePhotographyCount.value);
    }
    if (likeLocationCount.present) {
      map['like_location_count'] = Variable<int>(likeLocationCount.value);
    }
    if (likeArtCount.present) {
      map['like_art_count'] = Variable<int>(likeArtCount.value);
    }
    if (hasLike.present) {
      map['has_like'] = Variable<bool>(hasLike.value);
    }
    if (hasLikePhotography.present) {
      map['has_like_photography'] = Variable<bool>(hasLikePhotography.value);
    }
    if (hasLikeLocation.present) {
      map['has_like_location'] = Variable<bool>(hasLikeLocation.value);
    }
    if (hasLikeArt.present) {
      map['has_like_art'] = Variable<bool>(hasLikeArt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinLikeEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('id: $id, ')
          ..write('likeCount: $likeCount, ')
          ..write('likePhotographyCount: $likePhotographyCount, ')
          ..write('likeLocationCount: $likeLocationCount, ')
          ..write('likeArtCount: $likeArtCount, ')
          ..write('hasLike: $hasLike, ')
          ..write('hasLikePhotography: $hasLikePhotography, ')
          ..write('hasLikeLocation: $hasLikeLocation, ')
          ..write('hasLikeArt: $hasLikeArt')
          ..write(')'))
        .toString();
  }
}

class $UserEntitiesTable extends UserEntities
    with TableInfo<$UserEntitiesTable, UserDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedBatchMeta = const VerificationMeta(
    'selectedBatch',
  );
  @override
  late final GeneratedColumn<int> selectedBatch = GeneratedColumn<int>(
    'selected_batch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SeasonEntity?, String>
  bestSeason = GeneratedColumn<String>(
    'best_season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<SeasonEntity?>($UserEntitiesTable.$converterbestSeasonn);
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    userId,
    username,
    selectedBatch,
    description,
    bestSeason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('selected_batch')) {
      context.handle(
        _selectedBatchMeta,
        selectedBatch.isAcceptableOrUnknown(
          data['selected_batch']!,
          _selectedBatchMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  UserDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      selectedBatch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selected_batch'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      bestSeason: $UserEntitiesTable.$converterbestSeasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}best_season'],
        ),
      ),
    );
  }

  @override
  $UserEntitiesTable createAlias(String alias) {
    return $UserEntitiesTable(attachedDatabase, alias);
  }

  static TypeConverter<SeasonEntity, String> $converterbestSeason =
      const SeasonConverter();
  static TypeConverter<SeasonEntity?, String?> $converterbestSeasonn =
      NullAwareTypeConverter.wrap($converterbestSeason);
}

class UserDb extends DataClass implements Insertable<UserDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String userId;
  final String username;
  final int? selectedBatch;
  final String? description;
  final SeasonEntity? bestSeason;
  const UserDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.userId,
    required this.username,
    this.selectedBatch,
    this.description,
    this.bestSeason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['user_id'] = Variable<String>(userId);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || selectedBatch != null) {
      map['selected_batch'] = Variable<int>(selectedBatch);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || bestSeason != null) {
      map['best_season'] = Variable<String>(
        $UserEntitiesTable.$converterbestSeasonn.toSql(bestSeason),
      );
    }
    return map;
  }

  UserEntitiesCompanion toCompanion(bool nullToAbsent) {
    return UserEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      userId: Value(userId),
      username: Value(username),
      selectedBatch: selectedBatch == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedBatch),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      bestSeason: bestSeason == null && nullToAbsent
          ? const Value.absent()
          : Value(bestSeason),
    );
  }

  factory UserDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      userId: serializer.fromJson<String>(json['userId']),
      username: serializer.fromJson<String>(json['username']),
      selectedBatch: serializer.fromJson<int?>(json['selectedBatch']),
      description: serializer.fromJson<String?>(json['description']),
      bestSeason: serializer.fromJson<SeasonEntity?>(json['bestSeason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'userId': serializer.toJson<String>(userId),
      'username': serializer.toJson<String>(username),
      'selectedBatch': serializer.toJson<int?>(selectedBatch),
      'description': serializer.toJson<String?>(description),
      'bestSeason': serializer.toJson<SeasonEntity?>(bestSeason),
    };
  }

  UserDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? userId,
    String? username,
    Value<int?> selectedBatch = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<SeasonEntity?> bestSeason = const Value.absent(),
  }) => UserDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    userId: userId ?? this.userId,
    username: username ?? this.username,
    selectedBatch: selectedBatch.present
        ? selectedBatch.value
        : this.selectedBatch,
    description: description.present ? description.value : this.description,
    bestSeason: bestSeason.present ? bestSeason.value : this.bestSeason,
  );
  UserDb copyWithCompanion(UserEntitiesCompanion data) {
    return UserDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      selectedBatch: data.selectedBatch.present
          ? data.selectedBatch.value
          : this.selectedBatch,
      description: data.description.present
          ? data.description.value
          : this.description,
      bestSeason: data.bestSeason.present
          ? data.bestSeason.value
          : this.bestSeason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('selectedBatch: $selectedBatch, ')
          ..write('description: $description, ')
          ..write('bestSeason: $bestSeason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    userId,
    username,
    selectedBatch,
    description,
    bestSeason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.selectedBatch == this.selectedBatch &&
          other.description == this.description &&
          other.bestSeason == this.bestSeason);
}

class UserEntitiesCompanion extends UpdateCompanion<UserDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> userId;
  final Value<String> username;
  final Value<int?> selectedBatch;
  final Value<String?> description;
  final Value<SeasonEntity?> bestSeason;
  const UserEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.selectedBatch = const Value.absent(),
    this.description = const Value.absent(),
    this.bestSeason = const Value.absent(),
  });
  UserEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String userId,
    required String username,
    this.selectedBatch = const Value.absent(),
    this.description = const Value.absent(),
    this.bestSeason = const Value.absent(),
  }) : ttl = Value(ttl),
       userId = Value(userId),
       username = Value(username);
  static Insertable<UserDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? userId,
    Expression<String>? username,
    Expression<int>? selectedBatch,
    Expression<String>? description,
    Expression<String>? bestSeason,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (selectedBatch != null) 'selected_batch': selectedBatch,
      if (description != null) 'description': description,
      if (bestSeason != null) 'best_season': bestSeason,
    });
  }

  UserEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? userId,
    Value<String>? username,
    Value<int?>? selectedBatch,
    Value<String?>? description,
    Value<SeasonEntity?>? bestSeason,
  }) {
    return UserEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      selectedBatch: selectedBatch ?? this.selectedBatch,
      description: description ?? this.description,
      bestSeason: bestSeason ?? this.bestSeason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (selectedBatch.present) {
      map['selected_batch'] = Variable<int>(selectedBatch.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (bestSeason.present) {
      map['best_season'] = Variable<String>(
        $UserEntitiesTable.$converterbestSeasonn.toSql(bestSeason.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('selectedBatch: $selectedBatch, ')
          ..write('description: $description, ')
          ..write('bestSeason: $bestSeason')
          ..write(')'))
        .toString();
  }
}

class $UserLikeEntitiesTable extends UserLikeEntities
    with TableInfo<$UserLikeEntitiesTable, UserLikeDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserLikeEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeCountMeta = const VerificationMeta(
    'likeCount',
  );
  @override
  late final GeneratedColumn<int> likeCount = GeneratedColumn<int>(
    'like_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likePhotographyCountMeta =
      const VerificationMeta('likePhotographyCount');
  @override
  late final GeneratedColumn<int> likePhotographyCount = GeneratedColumn<int>(
    'like_photography_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeLocationCountMeta = const VerificationMeta(
    'likeLocationCount',
  );
  @override
  late final GeneratedColumn<int> likeLocationCount = GeneratedColumn<int>(
    'like_location_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likeArtCountMeta = const VerificationMeta(
    'likeArtCount',
  );
  @override
  late final GeneratedColumn<int> likeArtCount = GeneratedColumn<int>(
    'like_art_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    userId,
    likeCount,
    likePhotographyCount,
    likeLocationCount,
    likeArtCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_like_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserLikeDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('like_count')) {
      context.handle(
        _likeCountMeta,
        likeCount.isAcceptableOrUnknown(data['like_count']!, _likeCountMeta),
      );
    } else if (isInserting) {
      context.missing(_likeCountMeta);
    }
    if (data.containsKey('like_photography_count')) {
      context.handle(
        _likePhotographyCountMeta,
        likePhotographyCount.isAcceptableOrUnknown(
          data['like_photography_count']!,
          _likePhotographyCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likePhotographyCountMeta);
    }
    if (data.containsKey('like_location_count')) {
      context.handle(
        _likeLocationCountMeta,
        likeLocationCount.isAcceptableOrUnknown(
          data['like_location_count']!,
          _likeLocationCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likeLocationCountMeta);
    }
    if (data.containsKey('like_art_count')) {
      context.handle(
        _likeArtCountMeta,
        likeArtCount.isAcceptableOrUnknown(
          data['like_art_count']!,
          _likeArtCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_likeArtCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  UserLikeDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserLikeDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      likeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_count'],
      )!,
      likePhotographyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_photography_count'],
      )!,
      likeLocationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_location_count'],
      )!,
      likeArtCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}like_art_count'],
      )!,
    );
  }

  @override
  $UserLikeEntitiesTable createAlias(String alias) {
    return $UserLikeEntitiesTable(attachedDatabase, alias);
  }
}

class UserLikeDb extends DataClass implements Insertable<UserLikeDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String userId;
  final int likeCount;
  final int likePhotographyCount;
  final int likeLocationCount;
  final int likeArtCount;
  const UserLikeDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.userId,
    required this.likeCount,
    required this.likePhotographyCount,
    required this.likeLocationCount,
    required this.likeArtCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['user_id'] = Variable<String>(userId);
    map['like_count'] = Variable<int>(likeCount);
    map['like_photography_count'] = Variable<int>(likePhotographyCount);
    map['like_location_count'] = Variable<int>(likeLocationCount);
    map['like_art_count'] = Variable<int>(likeArtCount);
    return map;
  }

  UserLikeEntitiesCompanion toCompanion(bool nullToAbsent) {
    return UserLikeEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      userId: Value(userId),
      likeCount: Value(likeCount),
      likePhotographyCount: Value(likePhotographyCount),
      likeLocationCount: Value(likeLocationCount),
      likeArtCount: Value(likeArtCount),
    );
  }

  factory UserLikeDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserLikeDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      userId: serializer.fromJson<String>(json['userId']),
      likeCount: serializer.fromJson<int>(json['likeCount']),
      likePhotographyCount: serializer.fromJson<int>(
        json['likePhotographyCount'],
      ),
      likeLocationCount: serializer.fromJson<int>(json['likeLocationCount']),
      likeArtCount: serializer.fromJson<int>(json['likeArtCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'userId': serializer.toJson<String>(userId),
      'likeCount': serializer.toJson<int>(likeCount),
      'likePhotographyCount': serializer.toJson<int>(likePhotographyCount),
      'likeLocationCount': serializer.toJson<int>(likeLocationCount),
      'likeArtCount': serializer.toJson<int>(likeArtCount),
    };
  }

  UserLikeDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? userId,
    int? likeCount,
    int? likePhotographyCount,
    int? likeLocationCount,
    int? likeArtCount,
  }) => UserLikeDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    userId: userId ?? this.userId,
    likeCount: likeCount ?? this.likeCount,
    likePhotographyCount: likePhotographyCount ?? this.likePhotographyCount,
    likeLocationCount: likeLocationCount ?? this.likeLocationCount,
    likeArtCount: likeArtCount ?? this.likeArtCount,
  );
  UserLikeDb copyWithCompanion(UserLikeEntitiesCompanion data) {
    return UserLikeDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      userId: data.userId.present ? data.userId.value : this.userId,
      likeCount: data.likeCount.present ? data.likeCount.value : this.likeCount,
      likePhotographyCount: data.likePhotographyCount.present
          ? data.likePhotographyCount.value
          : this.likePhotographyCount,
      likeLocationCount: data.likeLocationCount.present
          ? data.likeLocationCount.value
          : this.likeLocationCount,
      likeArtCount: data.likeArtCount.present
          ? data.likeArtCount.value
          : this.likeArtCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserLikeDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('likeCount: $likeCount, ')
          ..write('likePhotographyCount: $likePhotographyCount, ')
          ..write('likeLocationCount: $likeLocationCount, ')
          ..write('likeArtCount: $likeArtCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    userId,
    likeCount,
    likePhotographyCount,
    likeLocationCount,
    likeArtCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserLikeDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.userId == this.userId &&
          other.likeCount == this.likeCount &&
          other.likePhotographyCount == this.likePhotographyCount &&
          other.likeLocationCount == this.likeLocationCount &&
          other.likeArtCount == this.likeArtCount);
}

class UserLikeEntitiesCompanion extends UpdateCompanion<UserLikeDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> userId;
  final Value<int> likeCount;
  final Value<int> likePhotographyCount;
  final Value<int> likeLocationCount;
  final Value<int> likeArtCount;
  const UserLikeEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.userId = const Value.absent(),
    this.likeCount = const Value.absent(),
    this.likePhotographyCount = const Value.absent(),
    this.likeLocationCount = const Value.absent(),
    this.likeArtCount = const Value.absent(),
  });
  UserLikeEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String userId,
    required int likeCount,
    required int likePhotographyCount,
    required int likeLocationCount,
    required int likeArtCount,
  }) : ttl = Value(ttl),
       userId = Value(userId),
       likeCount = Value(likeCount),
       likePhotographyCount = Value(likePhotographyCount),
       likeLocationCount = Value(likeLocationCount),
       likeArtCount = Value(likeArtCount);
  static Insertable<UserLikeDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? userId,
    Expression<int>? likeCount,
    Expression<int>? likePhotographyCount,
    Expression<int>? likeLocationCount,
    Expression<int>? likeArtCount,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (userId != null) 'user_id': userId,
      if (likeCount != null) 'like_count': likeCount,
      if (likePhotographyCount != null)
        'like_photography_count': likePhotographyCount,
      if (likeLocationCount != null) 'like_location_count': likeLocationCount,
      if (likeArtCount != null) 'like_art_count': likeArtCount,
    });
  }

  UserLikeEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? userId,
    Value<int>? likeCount,
    Value<int>? likePhotographyCount,
    Value<int>? likeLocationCount,
    Value<int>? likeArtCount,
  }) {
    return UserLikeEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      userId: userId ?? this.userId,
      likeCount: likeCount ?? this.likeCount,
      likePhotographyCount: likePhotographyCount ?? this.likePhotographyCount,
      likeLocationCount: likeLocationCount ?? this.likeLocationCount,
      likeArtCount: likeArtCount ?? this.likeArtCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (likeCount.present) {
      map['like_count'] = Variable<int>(likeCount.value);
    }
    if (likePhotographyCount.present) {
      map['like_photography_count'] = Variable<int>(likePhotographyCount.value);
    }
    if (likeLocationCount.present) {
      map['like_location_count'] = Variable<int>(likeLocationCount.value);
    }
    if (likeArtCount.present) {
      map['like_art_count'] = Variable<int>(likeArtCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserLikeEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('likeCount: $likeCount, ')
          ..write('likePhotographyCount: $likePhotographyCount, ')
          ..write('likeLocationCount: $likeLocationCount, ')
          ..write('likeArtCount: $likeArtCount')
          ..write(')'))
        .toString();
  }
}

class $UserPinsEntitiesTable extends UserPinsEntities
    with TableInfo<$UserPinsEntitiesTable, UserPinsDb> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPinsEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _isarIdMeta = const VerificationMeta('isarId');
  @override
  late final GeneratedColumn<int> isarId = GeneratedColumn<int>(
    'isar_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<DateTime> ttl = GeneratedColumn<DateTime>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitsMeta = const VerificationMeta('hits');
  @override
  late final GeneratedColumn<int> hits = GeneratedColumn<int>(
    'hits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAliveMeta = const VerificationMeta(
    'keepAlive',
  );
  @override
  late final GeneratedColumn<bool> keepAlive = GeneratedColumn<bool>(
    'keep_alive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_alive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlySessionMeta = const VerificationMeta(
    'onlySession',
  );
  @override
  late final GeneratedColumn<bool> onlySession = GeneratedColumn<bool>(
    'only_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> pins =
      GeneratedColumn<String>(
        'pins',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($UserPinsEntitiesTable.$converterpins);
  @override
  List<GeneratedColumn> get $columns => [
    isarId,
    ttl,
    hits,
    keepAlive,
    onlySession,
    userId,
    pins,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_pins_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPinsDb> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('isar_id')) {
      context.handle(
        _isarIdMeta,
        isarId.isAcceptableOrUnknown(data['isar_id']!, _isarIdMeta),
      );
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('hits')) {
      context.handle(
        _hitsMeta,
        hits.isAcceptableOrUnknown(data['hits']!, _hitsMeta),
      );
    }
    if (data.containsKey('keep_alive')) {
      context.handle(
        _keepAliveMeta,
        keepAlive.isAcceptableOrUnknown(data['keep_alive']!, _keepAliveMeta),
      );
    }
    if (data.containsKey('only_session')) {
      context.handle(
        _onlySessionMeta,
        onlySession.isAcceptableOrUnknown(
          data['only_session']!,
          _onlySessionMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {isarId};
  @override
  UserPinsDb map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPinsDb(
      isarId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}isar_id'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ttl'],
      )!,
      hits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hits'],
      )!,
      keepAlive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_alive'],
      )!,
      onlySession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_session'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      pins: $UserPinsEntitiesTable.$converterpins.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}pins'],
        )!,
      ),
    );
  }

  @override
  $UserPinsEntitiesTable createAlias(String alias) {
    return $UserPinsEntitiesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterpins =
      const StringListConverter();
}

class UserPinsDb extends DataClass implements Insertable<UserPinsDb> {
  final int isarId;
  final DateTime ttl;
  final int hits;
  final bool keepAlive;
  final bool onlySession;
  final String userId;
  final List<String> pins;
  const UserPinsDb({
    required this.isarId,
    required this.ttl,
    required this.hits,
    required this.keepAlive,
    required this.onlySession,
    required this.userId,
    required this.pins,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['isar_id'] = Variable<int>(isarId);
    map['ttl'] = Variable<DateTime>(ttl);
    map['hits'] = Variable<int>(hits);
    map['keep_alive'] = Variable<bool>(keepAlive);
    map['only_session'] = Variable<bool>(onlySession);
    map['user_id'] = Variable<String>(userId);
    {
      map['pins'] = Variable<String>(
        $UserPinsEntitiesTable.$converterpins.toSql(pins),
      );
    }
    return map;
  }

  UserPinsEntitiesCompanion toCompanion(bool nullToAbsent) {
    return UserPinsEntitiesCompanion(
      isarId: Value(isarId),
      ttl: Value(ttl),
      hits: Value(hits),
      keepAlive: Value(keepAlive),
      onlySession: Value(onlySession),
      userId: Value(userId),
      pins: Value(pins),
    );
  }

  factory UserPinsDb.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPinsDb(
      isarId: serializer.fromJson<int>(json['isarId']),
      ttl: serializer.fromJson<DateTime>(json['ttl']),
      hits: serializer.fromJson<int>(json['hits']),
      keepAlive: serializer.fromJson<bool>(json['keepAlive']),
      onlySession: serializer.fromJson<bool>(json['onlySession']),
      userId: serializer.fromJson<String>(json['userId']),
      pins: serializer.fromJson<List<String>>(json['pins']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'isarId': serializer.toJson<int>(isarId),
      'ttl': serializer.toJson<DateTime>(ttl),
      'hits': serializer.toJson<int>(hits),
      'keepAlive': serializer.toJson<bool>(keepAlive),
      'onlySession': serializer.toJson<bool>(onlySession),
      'userId': serializer.toJson<String>(userId),
      'pins': serializer.toJson<List<String>>(pins),
    };
  }

  UserPinsDb copyWith({
    int? isarId,
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? userId,
    List<String>? pins,
  }) => UserPinsDb(
    isarId: isarId ?? this.isarId,
    ttl: ttl ?? this.ttl,
    hits: hits ?? this.hits,
    keepAlive: keepAlive ?? this.keepAlive,
    onlySession: onlySession ?? this.onlySession,
    userId: userId ?? this.userId,
    pins: pins ?? this.pins,
  );
  UserPinsDb copyWithCompanion(UserPinsEntitiesCompanion data) {
    return UserPinsDb(
      isarId: data.isarId.present ? data.isarId.value : this.isarId,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      hits: data.hits.present ? data.hits.value : this.hits,
      keepAlive: data.keepAlive.present ? data.keepAlive.value : this.keepAlive,
      onlySession: data.onlySession.present
          ? data.onlySession.value
          : this.onlySession,
      userId: data.userId.present ? data.userId.value : this.userId,
      pins: data.pins.present ? data.pins.value : this.pins,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPinsDb(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('pins: $pins')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(isarId, ttl, hits, keepAlive, onlySession, userId, pins);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPinsDb &&
          other.isarId == this.isarId &&
          other.ttl == this.ttl &&
          other.hits == this.hits &&
          other.keepAlive == this.keepAlive &&
          other.onlySession == this.onlySession &&
          other.userId == this.userId &&
          other.pins == this.pins);
}

class UserPinsEntitiesCompanion extends UpdateCompanion<UserPinsDb> {
  final Value<int> isarId;
  final Value<DateTime> ttl;
  final Value<int> hits;
  final Value<bool> keepAlive;
  final Value<bool> onlySession;
  final Value<String> userId;
  final Value<List<String>> pins;
  const UserPinsEntitiesCompanion({
    this.isarId = const Value.absent(),
    this.ttl = const Value.absent(),
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    this.userId = const Value.absent(),
    this.pins = const Value.absent(),
  });
  UserPinsEntitiesCompanion.insert({
    this.isarId = const Value.absent(),
    required DateTime ttl,
    this.hits = const Value.absent(),
    this.keepAlive = const Value.absent(),
    this.onlySession = const Value.absent(),
    required String userId,
    required List<String> pins,
  }) : ttl = Value(ttl),
       userId = Value(userId),
       pins = Value(pins);
  static Insertable<UserPinsDb> custom({
    Expression<int>? isarId,
    Expression<DateTime>? ttl,
    Expression<int>? hits,
    Expression<bool>? keepAlive,
    Expression<bool>? onlySession,
    Expression<String>? userId,
    Expression<String>? pins,
  }) {
    return RawValuesInsertable({
      if (isarId != null) 'isar_id': isarId,
      if (ttl != null) 'ttl': ttl,
      if (hits != null) 'hits': hits,
      if (keepAlive != null) 'keep_alive': keepAlive,
      if (onlySession != null) 'only_session': onlySession,
      if (userId != null) 'user_id': userId,
      if (pins != null) 'pins': pins,
    });
  }

  UserPinsEntitiesCompanion copyWith({
    Value<int>? isarId,
    Value<DateTime>? ttl,
    Value<int>? hits,
    Value<bool>? keepAlive,
    Value<bool>? onlySession,
    Value<String>? userId,
    Value<List<String>>? pins,
  }) {
    return UserPinsEntitiesCompanion(
      isarId: isarId ?? this.isarId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
      userId: userId ?? this.userId,
      pins: pins ?? this.pins,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (isarId.present) {
      map['isar_id'] = Variable<int>(isarId.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<DateTime>(ttl.value);
    }
    if (hits.present) {
      map['hits'] = Variable<int>(hits.value);
    }
    if (keepAlive.present) {
      map['keep_alive'] = Variable<bool>(keepAlive.value);
    }
    if (onlySession.present) {
      map['only_session'] = Variable<bool>(onlySession.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (pins.present) {
      map['pins'] = Variable<String>(
        $UserPinsEntitiesTable.$converterpins.toSql(pins.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPinsEntitiesCompanion(')
          ..write('isarId: $isarId, ')
          ..write('ttl: $ttl, ')
          ..write('hits: $hits, ')
          ..write('keepAlive: $keepAlive, ')
          ..write('onlySession: $onlySession, ')
          ..write('userId: $userId, ')
          ..write('pins: $pins')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GroupEntitiesTable groupEntities = $GroupEntitiesTable(this);
  late final $ImageEntitiesTable imageEntities = $ImageEntitiesTable(this);
  late final $MemberEntitiesTable memberEntities = $MemberEntitiesTable(this);
  late final $PinEntitiesTable pinEntities = $PinEntitiesTable(this);
  late final $PinLikeEntitiesTable pinLikeEntities = $PinLikeEntitiesTable(
    this,
  );
  late final $UserEntitiesTable userEntities = $UserEntitiesTable(this);
  late final $UserLikeEntitiesTable userLikeEntities = $UserLikeEntitiesTable(
    this,
  );
  late final $UserPinsEntitiesTable userPinsEntities = $UserPinsEntitiesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    groupEntities,
    imageEntities,
    memberEntities,
    pinEntities,
    pinLikeEntities,
    userEntities,
    userLikeEntities,
    userPinsEntities,
  ];
}

typedef $$GroupEntitiesTableCreateCompanionBuilder =
    GroupEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String groupId,
      required String name,
      required int visibility,
      required bool userIsMember,
      Value<String?> inviteUrl,
      Value<String?> groupAdmin,
      Value<String?> description,
      Value<bool> isActivated,
      Value<DateTime?> lastUpdated,
      Value<String?> link,
      Value<SeasonEntity?> bestSeason,
    });
typedef $$GroupEntitiesTableUpdateCompanionBuilder =
    GroupEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> groupId,
      Value<String> name,
      Value<int> visibility,
      Value<bool> userIsMember,
      Value<String?> inviteUrl,
      Value<String?> groupAdmin,
      Value<String?> description,
      Value<bool> isActivated,
      Value<DateTime?> lastUpdated,
      Value<String?> link,
      Value<SeasonEntity?> bestSeason,
    });

class $$GroupEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $GroupEntitiesTable> {
  $$GroupEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userIsMember => $composableBuilder(
    column: $table.userIsMember,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inviteUrl => $composableBuilder(
    column: $table.inviteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupAdmin => $composableBuilder(
    column: $table.groupAdmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SeasonEntity?, SeasonEntity, String>
  get bestSeason => $composableBuilder(
    column: $table.bestSeason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$GroupEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupEntitiesTable> {
  $$GroupEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userIsMember => $composableBuilder(
    column: $table.userIsMember,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inviteUrl => $composableBuilder(
    column: $table.inviteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupAdmin => $composableBuilder(
    column: $table.groupAdmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestSeason => $composableBuilder(
    column: $table.bestSeason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupEntitiesTable> {
  $$GroupEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userIsMember => $composableBuilder(
    column: $table.userIsMember,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inviteUrl =>
      $composableBuilder(column: $table.inviteUrl, builder: (column) => column);

  GeneratedColumn<String> get groupAdmin => $composableBuilder(
    column: $table.groupAdmin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActivated => $composableBuilder(
    column: $table.isActivated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SeasonEntity?, String> get bestSeason =>
      $composableBuilder(
        column: $table.bestSeason,
        builder: (column) => column,
      );
}

class $$GroupEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupEntitiesTable,
          GroupDb,
          $$GroupEntitiesTableFilterComposer,
          $$GroupEntitiesTableOrderingComposer,
          $$GroupEntitiesTableAnnotationComposer,
          $$GroupEntitiesTableCreateCompanionBuilder,
          $$GroupEntitiesTableUpdateCompanionBuilder,
          (
            GroupDb,
            BaseReferences<_$AppDatabase, $GroupEntitiesTable, GroupDb>,
          ),
          GroupDb,
          PrefetchHooks Function()
        > {
  $$GroupEntitiesTableTableManager(_$AppDatabase db, $GroupEntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> visibility = const Value.absent(),
                Value<bool> userIsMember = const Value.absent(),
                Value<String?> inviteUrl = const Value.absent(),
                Value<String?> groupAdmin = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<SeasonEntity?> bestSeason = const Value.absent(),
              }) => GroupEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                groupId: groupId,
                name: name,
                visibility: visibility,
                userIsMember: userIsMember,
                inviteUrl: inviteUrl,
                groupAdmin: groupAdmin,
                description: description,
                isActivated: isActivated,
                lastUpdated: lastUpdated,
                link: link,
                bestSeason: bestSeason,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String groupId,
                required String name,
                required int visibility,
                required bool userIsMember,
                Value<String?> inviteUrl = const Value.absent(),
                Value<String?> groupAdmin = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActivated = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<String?> link = const Value.absent(),
                Value<SeasonEntity?> bestSeason = const Value.absent(),
              }) => GroupEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                groupId: groupId,
                name: name,
                visibility: visibility,
                userIsMember: userIsMember,
                inviteUrl: inviteUrl,
                groupAdmin: groupAdmin,
                description: description,
                isActivated: isActivated,
                lastUpdated: lastUpdated,
                link: link,
                bestSeason: bestSeason,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupEntitiesTable,
      GroupDb,
      $$GroupEntitiesTableFilterComposer,
      $$GroupEntitiesTableOrderingComposer,
      $$GroupEntitiesTableAnnotationComposer,
      $$GroupEntitiesTableCreateCompanionBuilder,
      $$GroupEntitiesTableUpdateCompanionBuilder,
      (GroupDb, BaseReferences<_$AppDatabase, $GroupEntitiesTable, GroupDb>),
      GroupDb,
      PrefetchHooks Function()
    >;
typedef $$ImageEntitiesTableCreateCompanionBuilder =
    ImageEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String id,
      required ImageType type,
      Value<Uint8List?> image,
    });
typedef $$ImageEntitiesTableUpdateCompanionBuilder =
    ImageEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> id,
      Value<ImageType> type,
      Value<Uint8List?> image,
    });

class $$ImageEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ImageEntitiesTable> {
  $$ImageEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImageType, ImageType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<Uint8List> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImageEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageEntitiesTable> {
  $$ImageEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageEntitiesTable> {
  $$ImageEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ImageType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<Uint8List> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);
}

class $$ImageEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageEntitiesTable,
          ImageDb,
          $$ImageEntitiesTableFilterComposer,
          $$ImageEntitiesTableOrderingComposer,
          $$ImageEntitiesTableAnnotationComposer,
          $$ImageEntitiesTableCreateCompanionBuilder,
          $$ImageEntitiesTableUpdateCompanionBuilder,
          (
            ImageDb,
            BaseReferences<_$AppDatabase, $ImageEntitiesTable, ImageDb>,
          ),
          ImageDb,
          PrefetchHooks Function()
        > {
  $$ImageEntitiesTableTableManager(_$AppDatabase db, $ImageEntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<ImageType> type = const Value.absent(),
                Value<Uint8List?> image = const Value.absent(),
              }) => ImageEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                id: id,
                type: type,
                image: image,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String id,
                required ImageType type,
                Value<Uint8List?> image = const Value.absent(),
              }) => ImageEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                id: id,
                type: type,
                image: image,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImageEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageEntitiesTable,
      ImageDb,
      $$ImageEntitiesTableFilterComposer,
      $$ImageEntitiesTableOrderingComposer,
      $$ImageEntitiesTableAnnotationComposer,
      $$ImageEntitiesTableCreateCompanionBuilder,
      $$ImageEntitiesTableUpdateCompanionBuilder,
      (ImageDb, BaseReferences<_$AppDatabase, $ImageEntitiesTable, ImageDb>),
      ImageDb,
      PrefetchHooks Function()
    >;
typedef $$MemberEntitiesTableCreateCompanionBuilder =
    MemberEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String groupId,
      required List<Map<String, dynamic>> members,
    });
typedef $$MemberEntitiesTableUpdateCompanionBuilder =
    MemberEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> groupId,
      Value<List<Map<String, dynamic>>> members,
    });

class $$MemberEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $MemberEntitiesTable> {
  $$MemberEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    List<Map<String, dynamic>>,
    List<Map<String, dynamic>>,
    String
  >
  get members => $composableBuilder(
    column: $table.members,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$MemberEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemberEntitiesTable> {
  $$MemberEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get members => $composableBuilder(
    column: $table.members,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemberEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemberEntitiesTable> {
  $$MemberEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Map<String, dynamic>>, String>
  get members =>
      $composableBuilder(column: $table.members, builder: (column) => column);
}

class $$MemberEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemberEntitiesTable,
          MemberDb,
          $$MemberEntitiesTableFilterComposer,
          $$MemberEntitiesTableOrderingComposer,
          $$MemberEntitiesTableAnnotationComposer,
          $$MemberEntitiesTableCreateCompanionBuilder,
          $$MemberEntitiesTableUpdateCompanionBuilder,
          (
            MemberDb,
            BaseReferences<_$AppDatabase, $MemberEntitiesTable, MemberDb>,
          ),
          MemberDb,
          PrefetchHooks Function()
        > {
  $$MemberEntitiesTableTableManager(
    _$AppDatabase db,
    $MemberEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemberEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemberEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemberEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<List<Map<String, dynamic>>> members =
                    const Value.absent(),
              }) => MemberEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                groupId: groupId,
                members: members,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String groupId,
                required List<Map<String, dynamic>> members,
              }) => MemberEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                groupId: groupId,
                members: members,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemberEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemberEntitiesTable,
      MemberDb,
      $$MemberEntitiesTableFilterComposer,
      $$MemberEntitiesTableOrderingComposer,
      $$MemberEntitiesTableAnnotationComposer,
      $$MemberEntitiesTableCreateCompanionBuilder,
      $$MemberEntitiesTableUpdateCompanionBuilder,
      (MemberDb, BaseReferences<_$AppDatabase, $MemberEntitiesTable, MemberDb>),
      MemberDb,
      PrefetchHooks Function()
    >;
typedef $$PinEntitiesTableCreateCompanionBuilder =
    PinEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String pinId,
      required double latitude,
      required double longitude,
      required DateTime creationDate,
      Value<String?> description,
      required String creator,
      required String groupId,
      Value<bool> isHidden,
      Value<DateTime?> lastSynced,
    });
typedef $$PinEntitiesTableUpdateCompanionBuilder =
    PinEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> pinId,
      Value<double> latitude,
      Value<double> longitude,
      Value<DateTime> creationDate,
      Value<String?> description,
      Value<String> creator,
      Value<String> groupId,
      Value<bool> isHidden,
      Value<DateTime?> lastSynced,
    });

class $$PinEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $PinEntitiesTable> {
  $$PinEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinId => $composableBuilder(
    column: $table.pinId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PinEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $PinEntitiesTable> {
  $$PinEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinId => $composableBuilder(
    column: $table.pinId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creator => $composableBuilder(
    column: $table.creator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PinEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinEntitiesTable> {
  $$PinEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinId =>
      $composableBuilder(column: $table.pinId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get creator =>
      $composableBuilder(column: $table.creator, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => column,
  );
}

class $$PinEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PinEntitiesTable,
          PinDb,
          $$PinEntitiesTableFilterComposer,
          $$PinEntitiesTableOrderingComposer,
          $$PinEntitiesTableAnnotationComposer,
          $$PinEntitiesTableCreateCompanionBuilder,
          $$PinEntitiesTableUpdateCompanionBuilder,
          (PinDb, BaseReferences<_$AppDatabase, $PinEntitiesTable, PinDb>),
          PinDb,
          PrefetchHooks Function()
        > {
  $$PinEntitiesTableTableManager(_$AppDatabase db, $PinEntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> pinId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<DateTime> creationDate = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> creator = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> lastSynced = const Value.absent(),
              }) => PinEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                pinId: pinId,
                latitude: latitude,
                longitude: longitude,
                creationDate: creationDate,
                description: description,
                creator: creator,
                groupId: groupId,
                isHidden: isHidden,
                lastSynced: lastSynced,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String pinId,
                required double latitude,
                required double longitude,
                required DateTime creationDate,
                Value<String?> description = const Value.absent(),
                required String creator,
                required String groupId,
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> lastSynced = const Value.absent(),
              }) => PinEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                pinId: pinId,
                latitude: latitude,
                longitude: longitude,
                creationDate: creationDate,
                description: description,
                creator: creator,
                groupId: groupId,
                isHidden: isHidden,
                lastSynced: lastSynced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PinEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PinEntitiesTable,
      PinDb,
      $$PinEntitiesTableFilterComposer,
      $$PinEntitiesTableOrderingComposer,
      $$PinEntitiesTableAnnotationComposer,
      $$PinEntitiesTableCreateCompanionBuilder,
      $$PinEntitiesTableUpdateCompanionBuilder,
      (PinDb, BaseReferences<_$AppDatabase, $PinEntitiesTable, PinDb>),
      PinDb,
      PrefetchHooks Function()
    >;
typedef $$PinLikeEntitiesTableCreateCompanionBuilder =
    PinLikeEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String id,
      required int likeCount,
      required int likePhotographyCount,
      required int likeLocationCount,
      required int likeArtCount,
      required bool hasLike,
      required bool hasLikePhotography,
      required bool hasLikeLocation,
      required bool hasLikeArt,
    });
typedef $$PinLikeEntitiesTableUpdateCompanionBuilder =
    PinLikeEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> id,
      Value<int> likeCount,
      Value<int> likePhotographyCount,
      Value<int> likeLocationCount,
      Value<int> likeArtCount,
      Value<bool> hasLike,
      Value<bool> hasLikePhotography,
      Value<bool> hasLikeLocation,
      Value<bool> hasLikeArt,
    });

class $$PinLikeEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $PinLikeEntitiesTable> {
  $$PinLikeEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLike => $composableBuilder(
    column: $table.hasLike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLikePhotography => $composableBuilder(
    column: $table.hasLikePhotography,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLikeLocation => $composableBuilder(
    column: $table.hasLikeLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasLikeArt => $composableBuilder(
    column: $table.hasLikeArt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PinLikeEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $PinLikeEntitiesTable> {
  $$PinLikeEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLike => $composableBuilder(
    column: $table.hasLike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLikePhotography => $composableBuilder(
    column: $table.hasLikePhotography,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLikeLocation => $composableBuilder(
    column: $table.hasLikeLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasLikeArt => $composableBuilder(
    column: $table.hasLikeArt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PinLikeEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinLikeEntitiesTable> {
  $$PinLikeEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get likeCount =>
      $composableBuilder(column: $table.likeCount, builder: (column) => column);

  GeneratedColumn<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasLike =>
      $composableBuilder(column: $table.hasLike, builder: (column) => column);

  GeneratedColumn<bool> get hasLikePhotography => $composableBuilder(
    column: $table.hasLikePhotography,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasLikeLocation => $composableBuilder(
    column: $table.hasLikeLocation,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasLikeArt => $composableBuilder(
    column: $table.hasLikeArt,
    builder: (column) => column,
  );
}

class $$PinLikeEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PinLikeEntitiesTable,
          PinLikeDb,
          $$PinLikeEntitiesTableFilterComposer,
          $$PinLikeEntitiesTableOrderingComposer,
          $$PinLikeEntitiesTableAnnotationComposer,
          $$PinLikeEntitiesTableCreateCompanionBuilder,
          $$PinLikeEntitiesTableUpdateCompanionBuilder,
          (
            PinLikeDb,
            BaseReferences<_$AppDatabase, $PinLikeEntitiesTable, PinLikeDb>,
          ),
          PinLikeDb,
          PrefetchHooks Function()
        > {
  $$PinLikeEntitiesTableTableManager(
    _$AppDatabase db,
    $PinLikeEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinLikeEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinLikeEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinLikeEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> likeCount = const Value.absent(),
                Value<int> likePhotographyCount = const Value.absent(),
                Value<int> likeLocationCount = const Value.absent(),
                Value<int> likeArtCount = const Value.absent(),
                Value<bool> hasLike = const Value.absent(),
                Value<bool> hasLikePhotography = const Value.absent(),
                Value<bool> hasLikeLocation = const Value.absent(),
                Value<bool> hasLikeArt = const Value.absent(),
              }) => PinLikeEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                id: id,
                likeCount: likeCount,
                likePhotographyCount: likePhotographyCount,
                likeLocationCount: likeLocationCount,
                likeArtCount: likeArtCount,
                hasLike: hasLike,
                hasLikePhotography: hasLikePhotography,
                hasLikeLocation: hasLikeLocation,
                hasLikeArt: hasLikeArt,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String id,
                required int likeCount,
                required int likePhotographyCount,
                required int likeLocationCount,
                required int likeArtCount,
                required bool hasLike,
                required bool hasLikePhotography,
                required bool hasLikeLocation,
                required bool hasLikeArt,
              }) => PinLikeEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                id: id,
                likeCount: likeCount,
                likePhotographyCount: likePhotographyCount,
                likeLocationCount: likeLocationCount,
                likeArtCount: likeArtCount,
                hasLike: hasLike,
                hasLikePhotography: hasLikePhotography,
                hasLikeLocation: hasLikeLocation,
                hasLikeArt: hasLikeArt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PinLikeEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PinLikeEntitiesTable,
      PinLikeDb,
      $$PinLikeEntitiesTableFilterComposer,
      $$PinLikeEntitiesTableOrderingComposer,
      $$PinLikeEntitiesTableAnnotationComposer,
      $$PinLikeEntitiesTableCreateCompanionBuilder,
      $$PinLikeEntitiesTableUpdateCompanionBuilder,
      (
        PinLikeDb,
        BaseReferences<_$AppDatabase, $PinLikeEntitiesTable, PinLikeDb>,
      ),
      PinLikeDb,
      PrefetchHooks Function()
    >;
typedef $$UserEntitiesTableCreateCompanionBuilder =
    UserEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String userId,
      required String username,
      Value<int?> selectedBatch,
      Value<String?> description,
      Value<SeasonEntity?> bestSeason,
    });
typedef $$UserEntitiesTableUpdateCompanionBuilder =
    UserEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> userId,
      Value<String> username,
      Value<int?> selectedBatch,
      Value<String?> description,
      Value<SeasonEntity?> bestSeason,
    });

class $$UserEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $UserEntitiesTable> {
  $$UserEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selectedBatch => $composableBuilder(
    column: $table.selectedBatch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SeasonEntity?, SeasonEntity, String>
  get bestSeason => $composableBuilder(
    column: $table.bestSeason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$UserEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserEntitiesTable> {
  $$UserEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selectedBatch => $composableBuilder(
    column: $table.selectedBatch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bestSeason => $composableBuilder(
    column: $table.bestSeason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserEntitiesTable> {
  $$UserEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<int> get selectedBatch => $composableBuilder(
    column: $table.selectedBatch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SeasonEntity?, String> get bestSeason =>
      $composableBuilder(
        column: $table.bestSeason,
        builder: (column) => column,
      );
}

class $$UserEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserEntitiesTable,
          UserDb,
          $$UserEntitiesTableFilterComposer,
          $$UserEntitiesTableOrderingComposer,
          $$UserEntitiesTableAnnotationComposer,
          $$UserEntitiesTableCreateCompanionBuilder,
          $$UserEntitiesTableUpdateCompanionBuilder,
          (UserDb, BaseReferences<_$AppDatabase, $UserEntitiesTable, UserDb>),
          UserDb,
          PrefetchHooks Function()
        > {
  $$UserEntitiesTableTableManager(_$AppDatabase db, $UserEntitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<int?> selectedBatch = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<SeasonEntity?> bestSeason = const Value.absent(),
              }) => UserEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                username: username,
                selectedBatch: selectedBatch,
                description: description,
                bestSeason: bestSeason,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String userId,
                required String username,
                Value<int?> selectedBatch = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<SeasonEntity?> bestSeason = const Value.absent(),
              }) => UserEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                username: username,
                selectedBatch: selectedBatch,
                description: description,
                bestSeason: bestSeason,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserEntitiesTable,
      UserDb,
      $$UserEntitiesTableFilterComposer,
      $$UserEntitiesTableOrderingComposer,
      $$UserEntitiesTableAnnotationComposer,
      $$UserEntitiesTableCreateCompanionBuilder,
      $$UserEntitiesTableUpdateCompanionBuilder,
      (UserDb, BaseReferences<_$AppDatabase, $UserEntitiesTable, UserDb>),
      UserDb,
      PrefetchHooks Function()
    >;
typedef $$UserLikeEntitiesTableCreateCompanionBuilder =
    UserLikeEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String userId,
      required int likeCount,
      required int likePhotographyCount,
      required int likeLocationCount,
      required int likeArtCount,
    });
typedef $$UserLikeEntitiesTableUpdateCompanionBuilder =
    UserLikeEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> userId,
      Value<int> likeCount,
      Value<int> likePhotographyCount,
      Value<int> likeLocationCount,
      Value<int> likeArtCount,
    });

class $$UserLikeEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $UserLikeEntitiesTable> {
  $$UserLikeEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserLikeEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserLikeEntitiesTable> {
  $$UserLikeEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeCount => $composableBuilder(
    column: $table.likeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserLikeEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserLikeEntitiesTable> {
  $$UserLikeEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get likeCount =>
      $composableBuilder(column: $table.likeCount, builder: (column) => column);

  GeneratedColumn<int> get likePhotographyCount => $composableBuilder(
    column: $table.likePhotographyCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likeLocationCount => $composableBuilder(
    column: $table.likeLocationCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likeArtCount => $composableBuilder(
    column: $table.likeArtCount,
    builder: (column) => column,
  );
}

class $$UserLikeEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserLikeEntitiesTable,
          UserLikeDb,
          $$UserLikeEntitiesTableFilterComposer,
          $$UserLikeEntitiesTableOrderingComposer,
          $$UserLikeEntitiesTableAnnotationComposer,
          $$UserLikeEntitiesTableCreateCompanionBuilder,
          $$UserLikeEntitiesTableUpdateCompanionBuilder,
          (
            UserLikeDb,
            BaseReferences<_$AppDatabase, $UserLikeEntitiesTable, UserLikeDb>,
          ),
          UserLikeDb,
          PrefetchHooks Function()
        > {
  $$UserLikeEntitiesTableTableManager(
    _$AppDatabase db,
    $UserLikeEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserLikeEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserLikeEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserLikeEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> likeCount = const Value.absent(),
                Value<int> likePhotographyCount = const Value.absent(),
                Value<int> likeLocationCount = const Value.absent(),
                Value<int> likeArtCount = const Value.absent(),
              }) => UserLikeEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                likeCount: likeCount,
                likePhotographyCount: likePhotographyCount,
                likeLocationCount: likeLocationCount,
                likeArtCount: likeArtCount,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String userId,
                required int likeCount,
                required int likePhotographyCount,
                required int likeLocationCount,
                required int likeArtCount,
              }) => UserLikeEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                likeCount: likeCount,
                likePhotographyCount: likePhotographyCount,
                likeLocationCount: likeLocationCount,
                likeArtCount: likeArtCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserLikeEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserLikeEntitiesTable,
      UserLikeDb,
      $$UserLikeEntitiesTableFilterComposer,
      $$UserLikeEntitiesTableOrderingComposer,
      $$UserLikeEntitiesTableAnnotationComposer,
      $$UserLikeEntitiesTableCreateCompanionBuilder,
      $$UserLikeEntitiesTableUpdateCompanionBuilder,
      (
        UserLikeDb,
        BaseReferences<_$AppDatabase, $UserLikeEntitiesTable, UserLikeDb>,
      ),
      UserLikeDb,
      PrefetchHooks Function()
    >;
typedef $$UserPinsEntitiesTableCreateCompanionBuilder =
    UserPinsEntitiesCompanion Function({
      Value<int> isarId,
      required DateTime ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      required String userId,
      required List<String> pins,
    });
typedef $$UserPinsEntitiesTableUpdateCompanionBuilder =
    UserPinsEntitiesCompanion Function({
      Value<int> isarId,
      Value<DateTime> ttl,
      Value<int> hits,
      Value<bool> keepAlive,
      Value<bool> onlySession,
      Value<String> userId,
      Value<List<String>> pins,
    });

class $$UserPinsEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $UserPinsEntitiesTable> {
  $$UserPinsEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get pins =>
      $composableBuilder(
        column: $table.pins,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$UserPinsEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPinsEntitiesTable> {
  $$UserPinsEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get isarId => $composableBuilder(
    column: $table.isarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hits => $composableBuilder(
    column: $table.hits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAlive => $composableBuilder(
    column: $table.keepAlive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pins => $composableBuilder(
    column: $table.pins,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPinsEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPinsEntitiesTable> {
  $$UserPinsEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get isarId =>
      $composableBuilder(column: $table.isarId, builder: (column) => column);

  GeneratedColumn<DateTime> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<int> get hits =>
      $composableBuilder(column: $table.hits, builder: (column) => column);

  GeneratedColumn<bool> get keepAlive =>
      $composableBuilder(column: $table.keepAlive, builder: (column) => column);

  GeneratedColumn<bool> get onlySession => $composableBuilder(
    column: $table.onlySession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get pins =>
      $composableBuilder(column: $table.pins, builder: (column) => column);
}

class $$UserPinsEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPinsEntitiesTable,
          UserPinsDb,
          $$UserPinsEntitiesTableFilterComposer,
          $$UserPinsEntitiesTableOrderingComposer,
          $$UserPinsEntitiesTableAnnotationComposer,
          $$UserPinsEntitiesTableCreateCompanionBuilder,
          $$UserPinsEntitiesTableUpdateCompanionBuilder,
          (
            UserPinsDb,
            BaseReferences<_$AppDatabase, $UserPinsEntitiesTable, UserPinsDb>,
          ),
          UserPinsDb,
          PrefetchHooks Function()
        > {
  $$UserPinsEntitiesTableTableManager(
    _$AppDatabase db,
    $UserPinsEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPinsEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPinsEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPinsEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                Value<DateTime> ttl = const Value.absent(),
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<List<String>> pins = const Value.absent(),
              }) => UserPinsEntitiesCompanion(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                pins: pins,
              ),
          createCompanionCallback:
              ({
                Value<int> isarId = const Value.absent(),
                required DateTime ttl,
                Value<int> hits = const Value.absent(),
                Value<bool> keepAlive = const Value.absent(),
                Value<bool> onlySession = const Value.absent(),
                required String userId,
                required List<String> pins,
              }) => UserPinsEntitiesCompanion.insert(
                isarId: isarId,
                ttl: ttl,
                hits: hits,
                keepAlive: keepAlive,
                onlySession: onlySession,
                userId: userId,
                pins: pins,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPinsEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPinsEntitiesTable,
      UserPinsDb,
      $$UserPinsEntitiesTableFilterComposer,
      $$UserPinsEntitiesTableOrderingComposer,
      $$UserPinsEntitiesTableAnnotationComposer,
      $$UserPinsEntitiesTableCreateCompanionBuilder,
      $$UserPinsEntitiesTableUpdateCompanionBuilder,
      (
        UserPinsDb,
        BaseReferences<_$AppDatabase, $UserPinsEntitiesTable, UserPinsDb>,
      ),
      UserPinsDb,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GroupEntitiesTableTableManager get groupEntities =>
      $$GroupEntitiesTableTableManager(_db, _db.groupEntities);
  $$ImageEntitiesTableTableManager get imageEntities =>
      $$ImageEntitiesTableTableManager(_db, _db.imageEntities);
  $$MemberEntitiesTableTableManager get memberEntities =>
      $$MemberEntitiesTableTableManager(_db, _db.memberEntities);
  $$PinEntitiesTableTableManager get pinEntities =>
      $$PinEntitiesTableTableManager(_db, _db.pinEntities);
  $$PinLikeEntitiesTableTableManager get pinLikeEntities =>
      $$PinLikeEntitiesTableTableManager(_db, _db.pinLikeEntities);
  $$UserEntitiesTableTableManager get userEntities =>
      $$UserEntitiesTableTableManager(_db, _db.userEntities);
  $$UserLikeEntitiesTableTableManager get userLikeEntities =>
      $$UserLikeEntitiesTableTableManager(_db, _db.userLikeEntities);
  $$UserPinsEntitiesTableTableManager get userPinsEntities =>
      $$UserPinsEntitiesTableTableManager(_db, _db.userPinsEntities);
}
