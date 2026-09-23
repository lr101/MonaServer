//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminUserFilterDto {
  /// Returns a new [AdminUserFilterDto] instance.
  AdminUserFilterDto({
    this.createdAfter,
    this.createdBefore,
    this.email,
    this.id,
    this.includeAdmins = false,
    required this.resource,
    this.securityStatuses = const [],
    this.username,
    this.verifiedEmail,
  });

  DateTime? createdAfter;

  DateTime? createdBefore;

  String? email;

  String? id;

  bool includeAdmins;

  AdminUserFilterDtoResourceEnum resource;

  List<AdminSecurityState>? securityStatuses;

  String? username;

  bool? verifiedEmail;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminUserFilterDto &&
    other.createdAfter == createdAfter &&
    other.createdBefore == createdBefore &&
    other.email == email &&
    other.id == id &&
    other.includeAdmins == includeAdmins &&
    other.resource == resource &&
    _deepEquality.equals(other.securityStatuses, securityStatuses) &&
    other.username == username &&
    other.verifiedEmail == verifiedEmail;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (createdAfter == null ? 0 : createdAfter!.hashCode) +
    (createdBefore == null ? 0 : createdBefore!.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (id == null ? 0 : id!.hashCode) +
    (includeAdmins.hashCode) +
    (resource.hashCode) +
    (securityStatuses == null ? 0 : securityStatuses!.hashCode) +
    (username == null ? 0 : username!.hashCode) +
    (verifiedEmail == null ? 0 : verifiedEmail!.hashCode);

  @override
  String toString() => 'AdminUserFilterDto[createdAfter=$createdAfter, createdBefore=$createdBefore, email=$email, id=$id, includeAdmins=$includeAdmins, resource=$resource, securityStatuses=$securityStatuses, username=$username, verifiedEmail=$verifiedEmail]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
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
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
      json[r'includeAdmins'] = this.includeAdmins;
      json[r'resource'] = this.resource;
    if (this.securityStatuses != null) {
      json[r'securityStatuses'] = this.securityStatuses;
    } else {
      json[r'securityStatuses'] = null;
    }
    if (this.username != null) {
      json[r'username'] = this.username;
    } else {
      json[r'username'] = null;
    }
    if (this.verifiedEmail != null) {
      json[r'verifiedEmail'] = this.verifiedEmail;
    } else {
      json[r'verifiedEmail'] = null;
    }
    return json;
  }

  /// Returns a new [AdminUserFilterDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminUserFilterDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminUserFilterDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminUserFilterDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminUserFilterDto(
        createdAfter: mapDateTime(json, r'createdAfter', r''),
        createdBefore: mapDateTime(json, r'createdBefore', r''),
        email: mapValueOfType<String>(json, r'email'),
        id: mapValueOfType<String>(json, r'id'),
        includeAdmins: mapValueOfType<bool>(json, r'includeAdmins') ?? false,
        resource: AdminUserFilterDtoResourceEnum.fromJson(json[r'resource'])!,
        securityStatuses: AdminSecurityState.listFromJson(json[r'securityStatuses']),
        username: mapValueOfType<String>(json, r'username'),
        verifiedEmail: mapValueOfType<bool>(json, r'verifiedEmail'),
      );
    }
    return null;
  }

  static List<AdminUserFilterDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminUserFilterDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserFilterDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminUserFilterDto> mapFromJson(dynamic json) {
    final map = <String, AdminUserFilterDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminUserFilterDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminUserFilterDto-objects as value to a dart map
  static Map<String, List<AdminUserFilterDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminUserFilterDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminUserFilterDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'resource',
  };
}


class AdminUserFilterDtoResourceEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminUserFilterDtoResourceEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const accounts = AdminUserFilterDtoResourceEnum._(r'accounts');

  /// List of all possible values in this [enum][AdminUserFilterDtoResourceEnum].
  static const values = <AdminUserFilterDtoResourceEnum>[
    accounts,
  ];

  static AdminUserFilterDtoResourceEnum? fromJson(dynamic value) => AdminUserFilterDtoResourceEnumTypeTransformer().decode(value);

  static List<AdminUserFilterDtoResourceEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminUserFilterDtoResourceEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserFilterDtoResourceEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminUserFilterDtoResourceEnum] to String,
/// and [decode] dynamic data back to [AdminUserFilterDtoResourceEnum].
class AdminUserFilterDtoResourceEnumTypeTransformer {
  factory AdminUserFilterDtoResourceEnumTypeTransformer() => _instance ??= const AdminUserFilterDtoResourceEnumTypeTransformer._();

  const AdminUserFilterDtoResourceEnumTypeTransformer._();

  String encode(AdminUserFilterDtoResourceEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminUserFilterDtoResourceEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminUserFilterDtoResourceEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'accounts': return AdminUserFilterDtoResourceEnum.accounts;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminUserFilterDtoResourceEnumTypeTransformer] instance.
  static AdminUserFilterDtoResourceEnumTypeTransformer? _instance;
}
