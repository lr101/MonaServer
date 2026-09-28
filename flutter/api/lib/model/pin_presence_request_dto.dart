//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinPresenceRequestDto {
  /// Returns a new [PinPresenceRequestDto] instance.
  PinPresenceRequestDto({
    required this.state,
  });

  PinPresenceRequestDtoStateEnum state;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinPresenceRequestDto &&
    other.state == state;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (state.hashCode);

  @override
  String toString() => 'PinPresenceRequestDto[state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [PinPresenceRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinPresenceRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinPresenceRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinPresenceRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinPresenceRequestDto(
        state: PinPresenceRequestDtoStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<PinPresenceRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinPresenceRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinPresenceRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinPresenceRequestDto> mapFromJson(dynamic json) {
    final map = <String, PinPresenceRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinPresenceRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinPresenceRequestDto-objects as value to a dart map
  static Map<String, List<PinPresenceRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinPresenceRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinPresenceRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'state',
  };
}


class PinPresenceRequestDtoStateEnum {
  /// Instantiate a new enum with the provided [value].
  const PinPresenceRequestDtoStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const here = PinPresenceRequestDtoStateEnum._(r'here');
  static const gone = PinPresenceRequestDtoStateEnum._(r'gone');

  /// List of all possible values in this [enum][PinPresenceRequestDtoStateEnum].
  static const values = <PinPresenceRequestDtoStateEnum>[
    here,
    gone,
  ];

  static PinPresenceRequestDtoStateEnum? fromJson(dynamic value) => PinPresenceRequestDtoStateEnumTypeTransformer().decode(value);

  static List<PinPresenceRequestDtoStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinPresenceRequestDtoStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinPresenceRequestDtoStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PinPresenceRequestDtoStateEnum] to String,
/// and [decode] dynamic data back to [PinPresenceRequestDtoStateEnum].
class PinPresenceRequestDtoStateEnumTypeTransformer {
  factory PinPresenceRequestDtoStateEnumTypeTransformer() => _instance ??= const PinPresenceRequestDtoStateEnumTypeTransformer._();

  const PinPresenceRequestDtoStateEnumTypeTransformer._();

  String encode(PinPresenceRequestDtoStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PinPresenceRequestDtoStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PinPresenceRequestDtoStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'here': return PinPresenceRequestDtoStateEnum.here;
        case r'gone': return PinPresenceRequestDtoStateEnum.gone;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PinPresenceRequestDtoStateEnumTypeTransformer] instance.
  static PinPresenceRequestDtoStateEnumTypeTransformer? _instance;
}
