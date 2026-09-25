//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UpdateGroupDto {
  /// Returns a new [UpdateGroupDto] instance.
  UpdateGroupDto({
    this.description,
    this.name,
    this.profileImage,
    this.visibility,
    this.groupAdmin,
    this.link,
    this.pinStyle,
  });

  String? description;

  String? name;

  String? profileImage;

  /// The visibility of the group. 0 for public, 1 for private
  int? visibility;

  String? groupAdmin;

  String? link;

  UpdateGroupDtoPinStyleEnum? pinStyle;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UpdateGroupDto &&
    other.description == description &&
    other.name == name &&
    other.profileImage == profileImage &&
    other.visibility == visibility &&
    other.groupAdmin == groupAdmin &&
    other.link == link &&
    other.pinStyle == pinStyle;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (description == null ? 0 : description!.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (profileImage == null ? 0 : profileImage!.hashCode) +
    (visibility == null ? 0 : visibility!.hashCode) +
    (groupAdmin == null ? 0 : groupAdmin!.hashCode) +
    (link == null ? 0 : link!.hashCode) +
    (pinStyle == null ? 0 : pinStyle!.hashCode);

  @override
  String toString() => 'UpdateGroupDto[description=$description, name=$name, profileImage=$profileImage, visibility=$visibility, groupAdmin=$groupAdmin, link=$link, pinStyle=$pinStyle]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    if (this.profileImage != null) {
      json[r'profileImage'] = this.profileImage;
    } else {
      json[r'profileImage'] = null;
    }
    if (this.visibility != null) {
      json[r'visibility'] = this.visibility;
    } else {
      json[r'visibility'] = null;
    }
    if (this.groupAdmin != null) {
      json[r'groupAdmin'] = this.groupAdmin;
    } else {
      json[r'groupAdmin'] = null;
    }
    if (this.link != null) {
      json[r'link'] = this.link;
    } else {
      json[r'link'] = null;
    }
    if (this.pinStyle != null) {
      json[r'pinStyle'] = this.pinStyle;
    } else {
      json[r'pinStyle'] = null;
    }
    return json;
  }

  /// Returns a new [UpdateGroupDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UpdateGroupDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UpdateGroupDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UpdateGroupDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UpdateGroupDto(
        description: mapValueOfType<String>(json, r'description'),
        name: mapValueOfType<String>(json, r'name'),
        profileImage: mapValueOfType<String>(json, r'profileImage'),
        visibility: mapValueOfType<int>(json, r'visibility'),
        groupAdmin: mapValueOfType<String>(json, r'groupAdmin'),
        link: mapValueOfType<String>(json, r'link'),
        pinStyle: UpdateGroupDtoPinStyleEnum.fromJson(json[r'pinStyle']),
      );
    }
    return null;
  }

  static List<UpdateGroupDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateGroupDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateGroupDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UpdateGroupDto> mapFromJson(dynamic json) {
    final map = <String, UpdateGroupDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UpdateGroupDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UpdateGroupDto-objects as value to a dart map
  static Map<String, List<UpdateGroupDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UpdateGroupDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UpdateGroupDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


class UpdateGroupDtoPinStyleEnum {
  /// Instantiate a new enum with the provided [value].
  const UpdateGroupDtoPinStyleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const classic = UpdateGroupDtoPinStyleEnum._(r'classic');
  static const moss = UpdateGroupDtoPinStyleEnum._(r'moss');
  static const sunset = UpdateGroupDtoPinStyleEnum._(r'sunset');
  static const aurora = UpdateGroupDtoPinStyleEnum._(r'aurora');

  /// List of all possible values in this [enum][UpdateGroupDtoPinStyleEnum].
  static const values = <UpdateGroupDtoPinStyleEnum>[
    classic,
    moss,
    sunset,
    aurora,
  ];

  static UpdateGroupDtoPinStyleEnum? fromJson(dynamic value) => UpdateGroupDtoPinStyleEnumTypeTransformer().decode(value);

  static List<UpdateGroupDtoPinStyleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateGroupDtoPinStyleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateGroupDtoPinStyleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UpdateGroupDtoPinStyleEnum] to String,
/// and [decode] dynamic data back to [UpdateGroupDtoPinStyleEnum].
class UpdateGroupDtoPinStyleEnumTypeTransformer {
  factory UpdateGroupDtoPinStyleEnumTypeTransformer() => _instance ??= const UpdateGroupDtoPinStyleEnumTypeTransformer._();

  const UpdateGroupDtoPinStyleEnumTypeTransformer._();

  String encode(UpdateGroupDtoPinStyleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a UpdateGroupDtoPinStyleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UpdateGroupDtoPinStyleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'classic': return UpdateGroupDtoPinStyleEnum.classic;
        case r'moss': return UpdateGroupDtoPinStyleEnum.moss;
        case r'sunset': return UpdateGroupDtoPinStyleEnum.sunset;
        case r'aurora': return UpdateGroupDtoPinStyleEnum.aurora;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [UpdateGroupDtoPinStyleEnumTypeTransformer] instance.
  static UpdateGroupDtoPinStyleEnumTypeTransformer? _instance;
}
