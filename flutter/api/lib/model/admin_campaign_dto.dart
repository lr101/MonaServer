//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminCampaignDto {
  /// Returns a new [AdminCampaignDto] instance.
  AdminCampaignDto({
    required this.body,
    required this.channel,
    required this.createdAt,
    this.createdByUserId,
    required this.id,
    required this.name,
    required this.revision,
    required this.status,
    this.subject,
    this.title,
    required this.updatedAt,
  });

  String body;

  AdminCampaignChannel channel;

  DateTime createdAt;

  String? createdByUserId;

  String id;

  String name;

  /// Minimum value: 1
  int revision;

  AdminCampaignStatus status;

  String? subject;

  String? title;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminCampaignDto &&
    other.body == body &&
    other.channel == channel &&
    other.createdAt == createdAt &&
    other.createdByUserId == createdByUserId &&
    other.id == id &&
    other.name == name &&
    other.revision == revision &&
    other.status == status &&
    other.subject == subject &&
    other.title == title &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (body.hashCode) +
    (channel.hashCode) +
    (createdAt.hashCode) +
    (createdByUserId == null ? 0 : createdByUserId!.hashCode) +
    (id.hashCode) +
    (name.hashCode) +
    (revision.hashCode) +
    (status.hashCode) +
    (subject == null ? 0 : subject!.hashCode) +
    (title == null ? 0 : title!.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'AdminCampaignDto[body=$body, channel=$channel, createdAt=$createdAt, createdByUserId=$createdByUserId, id=$id, name=$name, revision=$revision, status=$status, subject=$subject, title=$title, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'body'] = this.body;
      json[r'channel'] = this.channel;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
    if (this.createdByUserId != null) {
      json[r'createdByUserId'] = this.createdByUserId;
    } else {
      json[r'createdByUserId'] = null;
    }
      json[r'id'] = this.id;
      json[r'name'] = this.name;
      json[r'revision'] = this.revision;
      json[r'status'] = this.status;
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
      json[r'updatedAt'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [AdminCampaignDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminCampaignDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminCampaignDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminCampaignDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminCampaignDto(
        body: mapValueOfType<String>(json, r'body')!,
        channel: AdminCampaignChannel.fromJson(json[r'channel'])!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        createdByUserId: mapValueOfType<String>(json, r'createdByUserId'),
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        status: AdminCampaignStatus.fromJson(json[r'status'])!,
        subject: mapValueOfType<String>(json, r'subject'),
        title: mapValueOfType<String>(json, r'title'),
        updatedAt: mapDateTime(json, r'updatedAt', r'')!,
      );
    }
    return null;
  }

  static List<AdminCampaignDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminCampaignDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminCampaignDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminCampaignDto> mapFromJson(dynamic json) {
    final map = <String, AdminCampaignDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminCampaignDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminCampaignDto-objects as value to a dart map
  static Map<String, List<AdminCampaignDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminCampaignDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminCampaignDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'body',
    'channel',
    'createdAt',
    'id',
    'name',
    'revision',
    'status',
    'updatedAt',
  };
}
