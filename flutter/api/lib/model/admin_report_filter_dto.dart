//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReportFilterDto {
  /// Returns a new [AdminReportFilterDto] instance.
  AdminReportFilterDto({
    this.assigneeUserId,
    this.createdAfter,
    this.createdBefore,
    required this.resource,
    this.statuses = const [],
    this.types = const [],
  });

  String? assigneeUserId;

  DateTime? createdAfter;

  DateTime? createdBefore;

  AdminReportFilterDtoResourceEnum resource;

  List<AdminReportStatus>? statuses;

  List<String>? types;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReportFilterDto &&
    other.assigneeUserId == assigneeUserId &&
    other.createdAfter == createdAfter &&
    other.createdBefore == createdBefore &&
    other.resource == resource &&
    _deepEquality.equals(other.statuses, statuses) &&
    _deepEquality.equals(other.types, types);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (assigneeUserId == null ? 0 : assigneeUserId!.hashCode) +
    (createdAfter == null ? 0 : createdAfter!.hashCode) +
    (createdBefore == null ? 0 : createdBefore!.hashCode) +
    (resource.hashCode) +
    (statuses == null ? 0 : statuses!.hashCode) +
    (types == null ? 0 : types!.hashCode);

  @override
  String toString() => 'AdminReportFilterDto[assigneeUserId=$assigneeUserId, createdAfter=$createdAfter, createdBefore=$createdBefore, resource=$resource, statuses=$statuses, types=$types]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.assigneeUserId != null) {
      json[r'assigneeUserId'] = this.assigneeUserId;
    } else {
      json[r'assigneeUserId'] = null;
    }
    if (this.createdAfter != null) {
      json[r'createdAfter'] = this.createdAfter!.toUtc().toIso8601String();
    } else {
      json[r'createdAfter'] = null;
    }
    if (this.createdBefore != null) {
      json[r'createdBefore'] = this.createdBefore!.toUtc().toIso8601String();
    } else {
      json[r'createdBefore'] = null;
    }
      json[r'resource'] = this.resource;
    if (this.statuses != null) {
      json[r'statuses'] = this.statuses;
    } else {
      json[r'statuses'] = null;
    }
    if (this.types != null) {
      json[r'types'] = this.types;
    } else {
      json[r'types'] = null;
    }
    return json;
  }

  /// Returns a new [AdminReportFilterDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReportFilterDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReportFilterDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReportFilterDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReportFilterDto(
        assigneeUserId: mapValueOfType<String>(json, r'assigneeUserId'),
        createdAfter: mapDateTime(json, r'createdAfter', r''),
        createdBefore: mapDateTime(json, r'createdBefore', r''),
        resource: AdminReportFilterDtoResourceEnum.fromJson(json[r'resource'])!,
        statuses: AdminReportStatus.listFromJson(json[r'statuses']),
        types: json[r'types'] is Iterable
            ? (json[r'types'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<AdminReportFilterDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportFilterDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportFilterDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReportFilterDto> mapFromJson(dynamic json) {
    final map = <String, AdminReportFilterDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReportFilterDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReportFilterDto-objects as value to a dart map
  static Map<String, List<AdminReportFilterDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReportFilterDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReportFilterDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'resource',
  };
}


class AdminReportFilterDtoResourceEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminReportFilterDtoResourceEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const reports = AdminReportFilterDtoResourceEnum._(r'reports');

  /// List of all possible values in this [enum][AdminReportFilterDtoResourceEnum].
  static const values = <AdminReportFilterDtoResourceEnum>[
    reports,
  ];

  static AdminReportFilterDtoResourceEnum? fromJson(dynamic value) => AdminReportFilterDtoResourceEnumTypeTransformer().decode(value);

  static List<AdminReportFilterDtoResourceEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportFilterDtoResourceEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportFilterDtoResourceEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminReportFilterDtoResourceEnum] to String,
/// and [decode] dynamic data back to [AdminReportFilterDtoResourceEnum].
class AdminReportFilterDtoResourceEnumTypeTransformer {
  factory AdminReportFilterDtoResourceEnumTypeTransformer() => _instance ??= const AdminReportFilterDtoResourceEnumTypeTransformer._();

  const AdminReportFilterDtoResourceEnumTypeTransformer._();

  String encode(AdminReportFilterDtoResourceEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminReportFilterDtoResourceEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminReportFilterDtoResourceEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'reports': return AdminReportFilterDtoResourceEnum.reports;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminReportFilterDtoResourceEnumTypeTransformer] instance.
  static AdminReportFilterDtoResourceEnumTypeTransformer? _instance;
}
