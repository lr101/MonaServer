//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportResolveActionDto {
  /// Returns a new [ReportResolveActionDto] instance.
  ReportResolveActionDto({
    required this.action,
    this.note,
  });

  ReportResolveActionDtoActionEnum action;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportResolveActionDto &&
    other.action == action &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'ReportResolveActionDto[action=$action, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [ReportResolveActionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportResolveActionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportResolveActionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportResolveActionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportResolveActionDto(
        action: ReportResolveActionDtoActionEnum.fromJson(json[r'action'])!,
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<ReportResolveActionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResolveActionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResolveActionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportResolveActionDto> mapFromJson(dynamic json) {
    final map = <String, ReportResolveActionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportResolveActionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportResolveActionDto-objects as value to a dart map
  static Map<String, List<ReportResolveActionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportResolveActionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportResolveActionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
  };
}


class ReportResolveActionDtoActionEnum {
  /// Instantiate a new enum with the provided [value].
  const ReportResolveActionDtoActionEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const reportResolve = ReportResolveActionDtoActionEnum._(r'report_resolve');

  /// List of all possible values in this [enum][ReportResolveActionDtoActionEnum].
  static const values = <ReportResolveActionDtoActionEnum>[
    reportResolve,
  ];

  static ReportResolveActionDtoActionEnum? fromJson(dynamic value) => ReportResolveActionDtoActionEnumTypeTransformer().decode(value);

  static List<ReportResolveActionDtoActionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportResolveActionDtoActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportResolveActionDtoActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ReportResolveActionDtoActionEnum] to String,
/// and [decode] dynamic data back to [ReportResolveActionDtoActionEnum].
class ReportResolveActionDtoActionEnumTypeTransformer {
  factory ReportResolveActionDtoActionEnumTypeTransformer() => _instance ??= const ReportResolveActionDtoActionEnumTypeTransformer._();

  const ReportResolveActionDtoActionEnumTypeTransformer._();

  String encode(ReportResolveActionDtoActionEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a ReportResolveActionDtoActionEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ReportResolveActionDtoActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'report_resolve': return ReportResolveActionDtoActionEnum.reportResolve;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [ReportResolveActionDtoActionEnumTypeTransformer] instance.
  static ReportResolveActionDtoActionEnumTypeTransformer? _instance;
}


