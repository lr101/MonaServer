import 'dart:convert';

import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// Drift type converters
class SeasonConverter extends TypeConverter<SeasonEntity, String> {
  const SeasonConverter();
  @override
  SeasonEntity fromSql(String fromDb) {
    final map = jsonDecode(fromDb) as Map<String, dynamic>;
    return SeasonEntity(
      seasonId: map['seasonId'] as String? ?? "",
      month: map['month'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      seasonNumber: map['seasonNumber'] as int? ?? 0,
      rank: map['rank'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
    );
  }

  @override
  String toSql(SeasonEntity value) {
    return jsonEncode({
      'seasonId': value.seasonId,
      'month': value.month,
      'year': value.year,
      'seasonNumber': value.seasonNumber,
      'rank': value.rank,
      'points': value.points,
    });
  }
}

class MembersConverter
    extends TypeConverter<List<Map<String, dynamic>>, String> {
  const MembersConverter();
  @override
  List<Map<String, dynamic>> fromSql(String fromDb) {
    return List<Map<String, dynamic>>.from(jsonDecode(fromDb) as List);
  }

  @override
  String toSql(List<Map<String, dynamic>> value) {
    return jsonEncode(value);
  }
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) {
    return List<String>.from(jsonDecode(fromDb) as List);
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

mixin CacheTable on Table {
  IntColumn get isarId => integer()();
  DateTimeColumn get ttl => dateTime()();
  IntColumn get hits => integer().withDefault(const Constant(1))();
  BoolColumn get keepAlive => boolean().withDefault(const Constant(false))();
  BoolColumn get onlySession => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {isarId};
}

@DataClassName('GroupDb')
class GroupEntities extends Table with CacheTable {
  TextColumn get groupId => text()();
  TextColumn get name => text()();
  IntColumn get visibility => integer()();
  BoolColumn get userIsMember => boolean()();
  TextColumn get inviteUrl => text().nullable()();
  TextColumn get groupAdmin => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActivated => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();
  TextColumn get link => text().nullable()();
  TextColumn get bestSeason => text().map(const SeasonConverter()).nullable()();
}

@DataClassName('ImageDb')
class ImageEntities extends Table with CacheTable {
  TextColumn get cacheKey => text()();
  TextColumn get id => text()();
  IntColumn get type => intEnum<ImageType>()();
  BlobColumn get image => blob().nullable()();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

@DataClassName('MemberDb')
class MemberEntities extends Table with CacheTable {
  TextColumn get groupId => text()();
  TextColumn get members => text().map(const MembersConverter())();
}

@DataClassName('PinDb')
class PinEntities extends Table with CacheTable {
  TextColumn get pinId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get creationDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get creator => text()();
  TextColumn get groupId => text()();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSynced => dateTime().nullable()();
}

@DataClassName('PinLikeDb')
class PinLikeEntities extends Table with CacheTable {
  TextColumn get id => text()();
  IntColumn get likeCount => integer()();
  IntColumn get likePhotographyCount => integer()();
  IntColumn get likeLocationCount => integer()();
  IntColumn get likeArtCount => integer()();
  BoolColumn get hasLike => boolean()();
  BoolColumn get hasLikePhotography => boolean()();
  BoolColumn get hasLikeLocation => boolean()();
  BoolColumn get hasLikeArt => boolean()();
}

@DataClassName('UserDb')
class UserEntities extends Table with CacheTable {
  TextColumn get userId => text()();
  TextColumn get username => text()();
  IntColumn get selectedBatch => integer().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get bestSeason => text().map(const SeasonConverter()).nullable()();
}

@DataClassName('UserLikeDb')
class UserLikeEntities extends Table with CacheTable {
  TextColumn get userId => text()();
  IntColumn get likeCount => integer()();
  IntColumn get likePhotographyCount => integer()();
  IntColumn get likeLocationCount => integer()();
  IntColumn get likeArtCount => integer()();
}

@DataClassName('UserPinsDb')
class UserPinsEntities extends Table with CacheTable {
  TextColumn get userId => text()();
  TextColumn get pins => text().map(const StringListConverter())();
}

@DriftDatabase(
  tables: [
    GroupEntities,
    ImageEntities,
    MemberEntities,
    PinEntities,
    PinLikeEntities,
    UserEntities,
    UserLikeEntities,
    UserPinsEntities,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.database.customStatement('''
          CREATE TABLE image_entities_new (
            cache_key TEXT NOT NULL PRIMARY KEY,
            isar_id INTEGER NOT NULL,
            ttl INTEGER NOT NULL,
            hits INTEGER NOT NULL DEFAULT 1,
            keep_alive INTEGER NOT NULL DEFAULT 0,
            only_session INTEGER NOT NULL DEFAULT 0,
            id TEXT NOT NULL,
            type INTEGER NOT NULL,
            image BLOB,
            last_accessed_at INTEGER
          )
        ''');
        await m.database.customStatement('''
          INSERT OR REPLACE INTO image_entities_new
            (cache_key, isar_id, ttl, hits, keep_alive, only_session, id, type, image, last_accessed_at)
          SELECT
            CASE type
              WHEN 0 THEN 'pin:'
              WHEN 1 THEN 'user:'
              WHEN 2 THEN 'userSmall:'
              WHEN 3 THEN 'group:'
              WHEN 4 THEN 'groupSmall:'
              WHEN 5 THEN 'groupPin:'
              ELSE 'unknown:'
            END || id,
            isar_id,
            ttl,
            hits,
            keep_alive,
            only_session,
            id,
            type,
            image,
            NULL
          FROM image_entities
        ''');
        await m.database.customStatement('DROP TABLE image_entities');
        await m.database.customStatement(
          'ALTER TABLE image_entities_new RENAME TO image_entities',
        );
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
