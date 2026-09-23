//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminJobRecipientDto {
  /// Returns a new [AdminJobRecipientDto] instance.
  AdminJobRecipientDto({
    required this.accountId,
    required this.attemptCount,
    required this.deviceCount,
    this.lastAttemptAt,
    required this.outcome,
    this.reason,
  });

  String accountId;

  /// Minimum value: 0
  int attemptCount;

  /// Minimum value: 0
  int deviceCount;

  DateTime? lastAttemptAt;

  AdminJobRecipientDtoOutcomeEnum outcome;

  String? reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminJobRecipientDto &&
    other.accountId == accountId &&
    other.attemptCount == attemptCount &&
    other.deviceCount == deviceCount &&
    other.lastAttemptAt == lastAttemptAt &&
    other.outcome == outcome &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (accountId.hashCode) +
    (attemptCount.hashCode) +
    (deviceCount.hashCode) +
    (lastAttemptAt == null ? 0 : lastAttemptAt!.hashCode) +
    (outcome.hashCode) +
    (reason == null ? 0 : reason!.hashCode);

  @override
  String toString() => 'AdminJobRecipientDto[accountId=$accountId, attemptCount=$attemptCount, deviceCount=$deviceCount, lastAttemptAt=$lastAttemptAt, outcome=$outcome, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'accountId'] = this.accountId;
      json[r'attemptCount'] = this.attemptCount;
      json[r'deviceCount'] = this.deviceCount;
    if (this.lastAttemptAt != null) {
      json[r'lastAttemptAt'] = this.lastAttemptAt!.toUtc().toIso8601String();
    } else {
      json[r'lastAttemptAt'] = null;
    }
      json[r'outcome'] = this.outcome;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    return json;
  }

  /// Returns a new [AdminJobRecipientDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminJobRecipientDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminJobRecipientDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminJobRecipientDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminJobRecipientDto(
        accountId: mapValueOfType<String>(json, r'accountId')!,
        attemptCount: mapValueOfType<int>(json, r'attemptCount')!,
        deviceCount: mapValueOfType<int>(json, r'deviceCount')!,
        lastAttemptAt: mapDateTime(json, r'lastAttemptAt', r''),
        outcome: AdminJobRecipientDtoOutcomeEnum.fromJson(json[r'outcome'])!,
        reason: mapValueOfType<String>(json, r'reason'),
      );
    }
    return null;
  }

  static List<AdminJobRecipientDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminJobRecipientDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminJobRecipientDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminJobRecipientDto> mapFromJson(dynamic json) {
    final map = <String, AdminJobRecipientDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminJobRecipientDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminJobRecipientDto-objects as value to a dart map
  static Map<String, List<AdminJobRecipientDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminJobRecipientDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminJobRecipientDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'accountId',
    'attemptCount',
    'deviceCount',
    'outcome',
  };
}


class AdminJobRecipientDtoOutcomeEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminJobRecipientDtoOutcomeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const skipped = AdminJobRecipientDtoOutcomeEnum._(r'skipped');
  static const secured = AdminJobRecipientDtoOutcomeEnum._(r'secured');
  static const queued = AdminJobRecipientDtoOutcomeEnum._(r'queued');
  static const providerAccepted = AdminJobRecipientDtoOutcomeEnum._(r'provider_accepted');
  static const failed = AdminJobRecipientDtoOutcomeEnum._(r'failed');
  static const unknownDelivery = AdminJobRecipientDtoOutcomeEnum._(r'unknown_delivery');

  /// List of all possible values in this [enum][AdminJobRecipientDtoOutcomeEnum].
  static const values = <AdminJobRecipientDtoOutcomeEnum>[
    skipped,
    secured,
    queued,
    providerAccepted,
    failed,
    unknownDelivery,
  ];

  static AdminJobRecipientDtoOutcomeEnum? fromJson(dynamic value) => AdminJobRecipientDtoOutcomeEnumTypeTransformer().decode(value);

  static List<AdminJobRecipientDtoOutcomeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminJobRecipientDtoOutcomeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminJobRecipientDtoOutcomeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminJobRecipientDtoOutcomeEnum] to String,
/// and [decode] dynamic data back to [AdminJobRecipientDtoOutcomeEnum].
class AdminJobRecipientDtoOutcomeEnumTypeTransformer {
  factory AdminJobRecipientDtoOutcomeEnumTypeTransformer() => _instance ??= const AdminJobRecipientDtoOutcomeEnumTypeTransformer._();

  const AdminJobRecipientDtoOutcomeEnumTypeTransformer._();

  String encode(AdminJobRecipientDtoOutcomeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminJobRecipientDtoOutcomeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminJobRecipientDtoOutcomeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'skipped': return AdminJobRecipientDtoOutcomeEnum.skipped;
        case r'secured': return AdminJobRecipientDtoOutcomeEnum.secured;
        case r'queued': return AdminJobRecipientDtoOutcomeEnum.queued;
        case r'provider_accepted': return AdminJobRecipientDtoOutcomeEnum.providerAccepted;
        case r'failed': return AdminJobRecipientDtoOutcomeEnum.failed;
        case r'unknown_delivery': return AdminJobRecipientDtoOutcomeEnum.unknownDelivery;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminJobRecipientDtoOutcomeEnumTypeTransformer] instance.
  static AdminJobRecipientDtoOutcomeEnumTypeTransformer? _instance;
}


