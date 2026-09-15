//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PushActionDto {
  /// Returns a new [PushActionDto] instance.
  PushActionDto({
    required this.action,
    this.body,
    this.title,
  });

  PushActionDtoActionEnum action;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? body;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? title;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PushActionDto &&
    other.action == action &&
    other.body == body &&
    other.title == title;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (body == null ? 0 : body!.hashCode) +
    (title == null ? 0 : title!.hashCode);

  @override
  String toString() => 'PushActionDto[action=$action, body=$body, title=$title]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.body != null) {
      json[r'body'] = this.body;
    } else {
      json[r'body'] = null;
    }
    if (this.title != null) {
      json[r'title'] = this.title;
    } else {
      json[r'title'] = null;
    }
    return json;
  }

  /// Returns a new [PushActionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PushActionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PushActionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PushActionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PushActionDto(
        action: PushActionDtoActionEnum.fromJson(json[r'action'])!,
        body: mapValueOfType<String>(json, r'body'),
        title: mapValueOfType<String>(json, r'title'),
      );
    }
    return null;
  }

  static List<PushActionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushActionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushActionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PushActionDto> mapFromJson(dynamic json) {
    final map = <String, PushActionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PushActionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PushActionDto-objects as value to a dart map
  static Map<String, List<PushActionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PushActionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PushActionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
  };
}


class PushActionDtoActionEnum {
  /// Instantiate a new enum with the provided [value].
  const PushActionDtoActionEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const push = PushActionDtoActionEnum._(r'push');

  /// List of all possible values in this [enum][PushActionDtoActionEnum].
  static const values = <PushActionDtoActionEnum>[
    push,
  ];

  static PushActionDtoActionEnum? fromJson(dynamic value) => PushActionDtoActionEnumTypeTransformer().decode(value);

  static List<PushActionDtoActionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PushActionDtoActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PushActionDtoActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [PushActionDtoActionEnum] to String,
/// and [decode] dynamic data back to [PushActionDtoActionEnum].
class PushActionDtoActionEnumTypeTransformer {
  factory PushActionDtoActionEnumTypeTransformer() => _instance ??= const PushActionDtoActionEnumTypeTransformer._();

  const PushActionDtoActionEnumTypeTransformer._();

  String encode(PushActionDtoActionEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a PushActionDtoActionEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  PushActionDtoActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'push': return PushActionDtoActionEnum.push;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [PushActionDtoActionEnumTypeTransformer] instance.
  static PushActionDtoActionEnumTypeTransformer? _instance;
}


