//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminCampaignContentDto {
  /// Returns a new [AdminCampaignContentDto] instance.
  AdminCampaignContentDto({
    required this.body,
    required this.channel,
    required this.name,
    this.subject,
    this.title,
  });

  String body;

  AdminCampaignChannel channel;

  String name;

  String? subject;

  String? title;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminCampaignContentDto &&
    other.body == body &&
    other.channel == channel &&
    other.name == name &&
    other.subject == subject &&
    other.title == title;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (body.hashCode) +
    (channel.hashCode) +
    (name.hashCode) +
    (subject == null ? 0 : subject!.hashCode) +
    (title == null ? 0 : title!.hashCode);

  @override
  String toString() => 'AdminCampaignContentDto[body=$body, channel=$channel, name=$name, subject=$subject, title=$title]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'body'] = this.body;
      json[r'channel'] = this.channel;
      json[r'name'] = this.name;
    if (this.subject != null) {
      json[r'subject'] = this.subject;
    } else {
      json[r'subject'] = null;
    }
    if (this.title != null) {
      json[r'title'] = this.title;
    } else {
      json[r'title'] = null;
    }
    return json;
  }

  /// Returns a new [AdminCampaignContentDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminCampaignContentDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminCampaignContentDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminCampaignContentDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminCampaignContentDto(
        body: mapValueOfType<String>(json, r'body')!,
        channel: AdminCampaignChannel.fromJson(json[r'channel'])!,
        name: mapValueOfType<String>(json, r'name')!,
        subject: mapValueOfType<String>(json, r'subject'),
        title: mapValueOfType<String>(json, r'title'),
      );
    }
    return null;
  }

  static List<AdminCampaignContentDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminCampaignContentDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminCampaignContentDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminCampaignContentDto> mapFromJson(dynamic json) {
    final map = <String, AdminCampaignContentDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminCampaignContentDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminCampaignContentDto-objects as value to a dart map
  static Map<String, List<AdminCampaignContentDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminCampaignContentDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminCampaignContentDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'body',
    'channel',
    'name',
  };
}
