//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SeasonDto {
  /// Returns a new [SeasonDto] instance.
  SeasonDto({
    required this.id,
    required this.month,
    required this.year,
    required this.seasonNumber,
  });

  String id;

  int month;

  int year;

  int seasonNumber;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SeasonDto &&
    other.id == id &&
    other.month == month &&
    other.year == year &&
    other.seasonNumber == seasonNumber;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (month.hashCode) +
    (year.hashCode) +
    (seasonNumber.hashCode);

  @override
  String toString() => 'SeasonDto[id=$id, month=$month, year=$year, seasonNumber=$seasonNumber]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'month'] = this.month;
      json[r'year'] = this.year;
      json[r'seasonNumber'] = this.seasonNumber;
    return json;
  }

  /// Returns a new [SeasonDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SeasonDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SeasonDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SeasonDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SeasonDto(
        id: mapValueOfType<String>(json, r'id')!,
        month: mapValueOfType<int>(json, r'month')!,
        year: mapValueOfType<int>(json, r'year')!,
        seasonNumber: mapValueOfType<int>(json, r'seasonNumber')!,
      );
    }
    return null;
  }

  static List<SeasonDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SeasonDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SeasonDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SeasonDto> mapFromJson(dynamic json) {
    final map = <String, SeasonDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SeasonDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SeasonDto-objects as value to a dart map
  static Map<String, List<SeasonDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SeasonDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SeasonDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'month',
    'year',
    'seasonNumber',
  };
}

