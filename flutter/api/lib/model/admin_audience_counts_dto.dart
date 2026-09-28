//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudienceCountsDto {
  /// Returns a new [AdminAudienceCountsDto] instance.
  AdminAudienceCountsDto({
    required this.accountAudienceCount,
    required this.deviceDeliveryCount,
    required this.excludedCount,
    required this.eligibleRecipientCount,
  });

  /// Minimum value: 0
  int accountAudienceCount;

  /// Minimum value: 0
  int deviceDeliveryCount;

  /// Minimum value: 0
  int excludedCount;

  /// Minimum value: 0
  int eligibleRecipientCount;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudienceCountsDto &&
    other.accountAudienceCount == accountAudienceCount &&
    other.deviceDeliveryCount == deviceDeliveryCount &&
    other.excludedCount == excludedCount &&
    other.eligibleRecipientCount == eligibleRecipientCount;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (accountAudienceCount.hashCode) +
    (deviceDeliveryCount.hashCode) +
    (excludedCount.hashCode) +
    (eligibleRecipientCount.hashCode);

  @override
  String toString() => 'AdminAudienceCountsDto[accountAudienceCount=$accountAudienceCount, deviceDeliveryCount=$deviceDeliveryCount, excludedCount=$excludedCount, eligibleRecipientCount=$eligibleRecipientCount]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'accountAudienceCount'] = this.accountAudienceCount;
      json[r'deviceDeliveryCount'] = this.deviceDeliveryCount;
      json[r'excludedCount'] = this.excludedCount;
      json[r'eligibleRecipientCount'] = this.eligibleRecipientCount;
    return json;
  }

  /// Returns a new [AdminAudienceCountsDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudienceCountsDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudienceCountsDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudienceCountsDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudienceCountsDto(
        accountAudienceCount: mapValueOfType<int>(json, r'accountAudienceCount')!,
        deviceDeliveryCount: mapValueOfType<int>(json, r'deviceDeliveryCount')!,
        excludedCount: mapValueOfType<int>(json, r'excludedCount')!,
        eligibleRecipientCount: mapValueOfType<int>(json, r'eligibleRecipientCount')!,
      );
    }
    return null;
  }

  static List<AdminAudienceCountsDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudienceCountsDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudienceCountsDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudienceCountsDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudienceCountsDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudienceCountsDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudienceCountsDto-objects as value to a dart map
  static Map<String, List<AdminAudienceCountsDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudienceCountsDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudienceCountsDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'accountAudienceCount',
    'deviceDeliveryCount',
    'excludedCount',
    'eligibleRecipientCount',
  };
}

