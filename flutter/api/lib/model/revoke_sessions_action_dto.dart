//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RevokeSessionsActionDto {
  /// Returns a new [RevokeSessionsActionDto] instance.
  RevokeSessionsActionDto({
    required this.action,
    required this.reason,
  });

  RevokeSessionsActionDtoActionEnum action;

  String reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RevokeSessionsActionDto &&
    other.action == action &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (reason.hashCode);

  @override
  String toString() => 'RevokeSessionsActionDto[action=$action, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'reason'] = this.reason;
    return json;
  }

  /// Returns a new [RevokeSessionsActionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RevokeSessionsActionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RevokeSessionsActionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RevokeSessionsActionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RevokeSessionsActionDto(
        action: RevokeSessionsActionDtoActionEnum.fromJson(json[r'action'])!,
        reason: mapValueOfType<String>(json, r'reason')!,
      );
    }
    return null;
  }

  static List<RevokeSessionsActionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RevokeSessionsActionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RevokeSessionsActionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RevokeSessionsActionDto> mapFromJson(dynamic json) {
    final map = <String, RevokeSessionsActionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RevokeSessionsActionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RevokeSessionsActionDto-objects as value to a dart map
  static Map<String, List<RevokeSessionsActionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RevokeSessionsActionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RevokeSessionsActionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'reason',
  };
}


class RevokeSessionsActionDtoActionEnum {
  /// Instantiate a new enum with the provided [value].
  const RevokeSessionsActionDtoActionEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const revokeSessions = RevokeSessionsActionDtoActionEnum._(r'revoke_sessions');

  /// List of all possible values in this [enum][RevokeSessionsActionDtoActionEnum].
  static const values = <RevokeSessionsActionDtoActionEnum>[
    revokeSessions,
  ];

  static RevokeSessionsActionDtoActionEnum? fromJson(dynamic value) => RevokeSessionsActionDtoActionEnumTypeTransformer().decode(value);

  static List<RevokeSessionsActionDtoActionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RevokeSessionsActionDtoActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RevokeSessionsActionDtoActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RevokeSessionsActionDtoActionEnum] to String,
/// and [decode] dynamic data back to [RevokeSessionsActionDtoActionEnum].
class RevokeSessionsActionDtoActionEnumTypeTransformer {
  factory RevokeSessionsActionDtoActionEnumTypeTransformer() => _instance ??= const RevokeSessionsActionDtoActionEnumTypeTransformer._();

  const RevokeSessionsActionDtoActionEnumTypeTransformer._();

  String encode(RevokeSessionsActionDtoActionEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a RevokeSessionsActionDtoActionEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RevokeSessionsActionDtoActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'revoke_sessions': return RevokeSessionsActionDtoActionEnum.revokeSessions;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [RevokeSessionsActionDtoActionEnumTypeTransformer] instance.
  static RevokeSessionsActionDtoActionEnumTypeTransformer? _instance;
}
