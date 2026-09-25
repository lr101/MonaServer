//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminLoginLinkCampaignRequestDto {
  /// Returns a new [AdminLoginLinkCampaignRequestDto] instance.
  AdminLoginLinkCampaignRequestDto({
    this.campaignId,
    this.campaignRevision,
    this.sendId,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? campaignId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? campaignRevision;

  /// Stable identifier for one send attempt, reused when retrying an uncertain request.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? sendId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminLoginLinkCampaignRequestDto &&
    other.campaignId == campaignId &&
    other.campaignRevision == campaignRevision &&
    other.sendId == sendId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (campaignId == null ? 0 : campaignId!.hashCode) +
    (campaignRevision == null ? 0 : campaignRevision!.hashCode) +
    (sendId == null ? 0 : sendId!.hashCode);

  @override
  String toString() => 'AdminLoginLinkCampaignRequestDto[campaignId=$campaignId, campaignRevision=$campaignRevision, sendId=$sendId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.campaignId != null) {
      json[r'campaignId'] = this.campaignId;
    } else {
      json[r'campaignId'] = null;
    }
    if (this.campaignRevision != null) {
      json[r'campaignRevision'] = this.campaignRevision;
    } else {
      json[r'campaignRevision'] = null;
    }
    if (this.sendId != null) {
      json[r'sendId'] = this.sendId;
    } else {
      json[r'sendId'] = null;
    }
    return json;
  }

  /// Returns a new [AdminLoginLinkCampaignRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminLoginLinkCampaignRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminLoginLinkCampaignRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminLoginLinkCampaignRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminLoginLinkCampaignRequestDto(
        campaignId: mapValueOfType<String>(json, r'campaignId'),
        campaignRevision: mapValueOfType<int>(json, r'campaignRevision'),
        sendId: mapValueOfType<String>(json, r'sendId'),
      );
    }
    return null;
  }

  static List<AdminLoginLinkCampaignRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminLoginLinkCampaignRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminLoginLinkCampaignRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminLoginLinkCampaignRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminLoginLinkCampaignRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminLoginLinkCampaignRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminLoginLinkCampaignRequestDto-objects as value to a dart map
  static Map<String, List<AdminLoginLinkCampaignRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminLoginLinkCampaignRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminLoginLinkCampaignRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}
