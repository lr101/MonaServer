//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SeasonItemDto {
  /// Returns a new [SeasonItemDto] instance.
  SeasonItemDto({
    required this.id,
    required this.season,
    required this.points,
    required this.rank,
  });

  String id;

  SeasonDto season;

  /// Number of sticks
  int points;

  /// Rank reached at the end of the season
  int rank;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SeasonItemDto &&
    other.id == id &&
    other.season == season &&
    other.points == points &&
    other.rank == rank;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (season.hashCode) +
    (points.hashCode) +
    (rank.hashCode);

  @override
  String toString() => 'SeasonItemDto[id=$id, season=$season, points=$points, rank=$rank]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'season'] = this.season;
      json[r'points'] = this.points;
      json[r'rank'] = this.rank;
    return json;
  }

  /// Returns a new [SeasonItemDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SeasonItemDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SeasonItemDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SeasonItemDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SeasonItemDto(
        id: mapValueOfType<String>(json, r'id')!,
        season: SeasonDto.fromJson(json[r'season'])!,
        points: mapValueOfType<int>(json, r'points')!,
        rank: mapValueOfType<int>(json, r'rank')!,
      );
    }
    return null;
  }

  static List<SeasonItemDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SeasonItemDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SeasonItemDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SeasonItemDto> mapFromJson(dynamic json) {
    final map = <String, SeasonItemDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SeasonItemDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SeasonItemDto-objects as value to a dart map
  static Map<String, List<SeasonItemDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SeasonItemDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SeasonItemDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'season',
    'points',
    'rank',
  };
}

