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

class MembersConverter extends TypeConverter<List<Map<String, dynamic>>, String> {
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
  TextColumn get id => text()();
  IntColumn get type => intEnum<ImageType>()();
  BlobColumn get image => blob().nullable()();
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

@DriftDatabase(tables: [
  GroupEntities,
  ImageEntities,
  MemberEntities,
  PinEntities,
  PinLikeEntities,
  UserEntities,
  UserLikeEntities,
  UserPinsEntities
])
class AppDatabase extends _$AppDatabase {

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;


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
