//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudienceFilter {
  /// Returns a new [AdminAudienceFilter] instance.
  AdminAudienceFilter({
    required this.resource,
    this.createdAfter,
    this.createdBefore,
    this.email,
    this.id,
    this.includeAdmins,
    this.securityStatuses,
    this.username,
    this.verifiedEmail,
    this.assigneeUserId,
    this.statuses,
    this.types,
  });

  AudienceResourceKind resource;

  DateTime? createdAfter;

  DateTime? createdBefore;

  String? email;

  String? id;

  bool? includeAdmins;

  List<AdminSecurityState>? securityStatuses;

  String? username;

  bool? verifiedEmail;

  String? assigneeUserId;

  List<AdminReportStatus>? statuses;

  List<String>? types;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudienceFilter &&
    other.resource == resource &&
    other.createdAfter == createdAfter &&
    other.createdBefore == createdBefore &&
    other.email == email &&
    other.id == id &&
    other.includeAdmins == includeAdmins &&
    _deepEquality.equals(other.securityStatuses, securityStatuses) &&
    other.username == username &&
    other.verifiedEmail == verifiedEmail &&
    other.assigneeUserId == assigneeUserId &&
    _deepEquality.equals(other.statuses, statuses) &&
    _deepEquality.equals(other.types, types);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (resource.hashCode) +
    (createdAfter == null ? 0 : createdAfter!.hashCode) +
    (createdBefore == null ? 0 : createdBefore!.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (id == null ? 0 : id!.hashCode) +
    (includeAdmins == null ? 0 : includeAdmins!.hashCode) +
    (securityStatuses == null ? 0 : securityStatuses!.hashCode) +
    (username == null ? 0 : username!.hashCode) +
    (verifiedEmail == null ? 0 : verifiedEmail!.hashCode) +
    (assigneeUserId == null ? 0 : assigneeUserId!.hashCode) +
    (statuses == null ? 0 : statuses!.hashCode) +
    (types == null ? 0 : types!.hashCode);

  @override
  String toString() => 'AdminAudienceFilter[resource=$resource, createdAfter=$createdAfter, createdBefore=$createdBefore, email=$email, id=$id, includeAdmins=$includeAdmins, securityStatuses=$securityStatuses, username=$username, verifiedEmail=$verifiedEmail, assigneeUserId=$assigneeUserId, statuses=$statuses, types=$types]';

  Map<String, dynamic> toJson() {
    if (this.resource.value == 'accounts' &&
        (this.assigneeUserId != null || this.statuses != null || this.types != null)) {
      throw const FormatException('Report filter fields require resource reports.');
    }
    if (this.resource.value == 'reports' &&
        (this.email != null || this.id != null || this.securityStatuses != null ||
            this.username != null || this.verifiedEmail != null || this.includeAdmins != null)) {
      throw const FormatException('Account filter fields require resource accounts.');
    }
    final json = <String, dynamic>{};
    json[r'resource'] = this.resource;
    if (this.createdAfter != null) {
      json[r'createdAfter'] = this.createdAfter!.toUtc().toIso8601String();
    }
    if (this.createdBefore != null) {
      json[r'createdBefore'] = this.createdBefore!.toUtc().toIso8601String();
    }
    if (this.email != null) {
      json[r'email'] = this.email;
    }
    if (this.id != null) {
      json[r'id'] = this.id;
    }
    if (this.resource.value == 'accounts' && this.includeAdmins != null) {
      json[r'includeAdmins'] = this.includeAdmins;
    }
    if (this.securityStatuses != null) {
      json[r'securityStatuses'] = this.securityStatuses;
    }
    if (this.username != null) {
      json[r'username'] = this.username;
    }
    if (this.verifiedEmail != null) {
      json[r'verifiedEmail'] = this.verifiedEmail;
    }
    if (this.assigneeUserId != null) {
      json[r'assigneeUserId'] = this.assigneeUserId;
    }
    if (this.statuses != null) {
      json[r'statuses'] = this.statuses;
    }
    if (this.types != null) {
      json[r'types'] = this.types;
    }
    return json;
  }

  /// Returns a new [AdminAudienceFilter] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudienceFilter? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();
      final resource = AudienceResourceKind.fromJson(json[r'resource']);
      if (resource == null) {
        throw const FormatException('AdminAudienceFilter requires a valid resource.');
      }
      final allowedKeys = <String>{
        'resource',
        'createdAfter',
        'createdBefore',
      };
      if (resource.value == 'accounts') {
        allowedKeys.addAll(<String>{
          'email',
          'id',
          'includeAdmins',
          'securityStatuses',
          'username',
          'verifiedEmail',
        });
        if (json.containsKey('includeAdmins') && json['includeAdmins'] == null) {
          throw const FormatException('includeAdmins cannot be null.');
        }
      } else if (resource.value == 'reports') {
        allowedKeys.addAll(<String>{'assigneeUserId', 'statuses', 'types'});
      }
      for (final key in json.keys) {
        if (!allowedKeys.contains(key)) {
          throw FormatException('Field "$key" is not valid for ${resource.value} audience filters.');
        }
      }
      return AdminAudienceFilter(
        resource: resource,
        createdAfter: mapDateTime(json, r'createdAfter', r''),
        createdBefore: mapDateTime(json, r'createdBefore', r''),
        email: mapValueOfType<String>(json, r'email'),
        id: mapValueOfType<String>(json, r'id'),
        includeAdmins: mapValueOfType<bool>(json, r'includeAdmins'),
        securityStatuses: AdminSecurityState.listFromJson(json[r'securityStatuses']),
        username: mapValueOfType<String>(json, r'username'),
        verifiedEmail: mapValueOfType<bool>(json, r'verifiedEmail'),
        assigneeUserId: mapValueOfType<String>(json, r'assigneeUserId'),
        statuses: AdminReportStatus.listFromJson(json[r'statuses']),
        types: (json[r'types'] as Iterable?)?.cast<String>().toList(growable: false),
      );
    }
    return null;
  }

  static List<AdminAudienceFilter> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudienceFilter>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudienceFilter.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudienceFilter> mapFromJson(dynamic json) {
    final map = <String, AdminAudienceFilter>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudienceFilter.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  static const requiredKeys = <String>{
    'resource',
  };
}
