//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupPinDesignDto {
  /// Returns a new [GroupPinDesignDto] instance.
  GroupPinDesignDto({
    required this.badge,
    required this.bodyColor,
    required this.imageBorderColor,
    required this.imageInset,
    required this.imageZoom,
    required this.imageAlignmentX,
    required this.imageAlignmentY,
    required this.name,
    required this.outlineColor,
    required this.outlineWidth,
    required this.shadow,
    required this.shape,
    required this.style,
  });

  GroupPinDesignBadge badge;

  String bodyColor;

  String imageBorderColor;

  /// Minimum value: 0
  /// Maximum value: 8
  num imageInset;

  /// Minimum value: 1
  /// Maximum value: 2.5
  num imageZoom;

  /// Minimum value: -1
  /// Maximum value: 1
  num imageAlignmentX;

  /// Minimum value: -1
  /// Maximum value: 1
  num imageAlignmentY;

  String name;

  String outlineColor;

  /// Minimum value: 0
  /// Maximum value: 5
  num outlineWidth;

  bool shadow;

  GroupPinDesignShape shape;

  GroupPinDesignStyle style;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupPinDesignDto &&
    other.badge == badge &&
    other.bodyColor == bodyColor &&
    other.imageBorderColor == imageBorderColor &&
    other.imageInset == imageInset &&
    other.imageZoom == imageZoom &&
    other.imageAlignmentX == imageAlignmentX &&
    other.imageAlignmentY == imageAlignmentY &&
    other.name == name &&
    other.outlineColor == outlineColor &&
    other.outlineWidth == outlineWidth &&
    other.shadow == shadow &&
    other.shape == shape &&
    other.style == style;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (badge.hashCode) +
    (bodyColor.hashCode) +
    (imageBorderColor.hashCode) +
    (imageInset.hashCode) +
    (imageZoom.hashCode) +
    (imageAlignmentX.hashCode) +
    (imageAlignmentY.hashCode) +
    (name.hashCode) +
    (outlineColor.hashCode) +
    (outlineWidth.hashCode) +
    (shadow.hashCode) +
    (shape.hashCode) +
    (style.hashCode);

  @override
  String toString() => 'GroupPinDesignDto[badge=$badge, bodyColor=$bodyColor, imageBorderColor=$imageBorderColor, imageInset=$imageInset, imageZoom=$imageZoom, imageAlignmentX=$imageAlignmentX, imageAlignmentY=$imageAlignmentY, name=$name, outlineColor=$outlineColor, outlineWidth=$outlineWidth, shadow=$shadow, shape=$shape, style=$style]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'badge'] = this.badge;
      json[r'bodyColor'] = this.bodyColor;
      json[r'imageBorderColor'] = this.imageBorderColor;
      json[r'imageInset'] = this.imageInset;
      json[r'imageZoom'] = this.imageZoom;
      json[r'imageAlignmentX'] = this.imageAlignmentX;
      json[r'imageAlignmentY'] = this.imageAlignmentY;
      json[r'name'] = this.name;
      json[r'outlineColor'] = this.outlineColor;
      json[r'outlineWidth'] = this.outlineWidth;
      json[r'shadow'] = this.shadow;
      json[r'shape'] = this.shape;
      json[r'style'] = this.style;
    return json;
  }

  /// Returns a new [GroupPinDesignDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupPinDesignDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupPinDesignDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupPinDesignDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupPinDesignDto(
        badge: GroupPinDesignBadge.fromJson(json[r'badge'])!,
        bodyColor: mapValueOfType<String>(json, r'bodyColor')!,
        imageBorderColor: mapValueOfType<String>(json, r'imageBorderColor')!,
        imageInset: num.parse('${json[r'imageInset']}'),
        imageZoom: num.parse('${json[r'imageZoom']}'),
        imageAlignmentX: num.parse('${json[r'imageAlignmentX']}'),
        imageAlignmentY: num.parse('${json[r'imageAlignmentY']}'),
        name: mapValueOfType<String>(json, r'name')!,
        outlineColor: mapValueOfType<String>(json, r'outlineColor')!,
        outlineWidth: num.parse('${json[r'outlineWidth']}'),
        shadow: mapValueOfType<bool>(json, r'shadow')!,
        shape: GroupPinDesignShape.fromJson(json[r'shape'])!,
        style: GroupPinDesignStyle.fromJson(json[r'style'])!,
      );
    }
    return null;
  }

  static List<GroupPinDesignDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupPinDesignDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupPinDesignDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupPinDesignDto> mapFromJson(dynamic json) {
    final map = <String, GroupPinDesignDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupPinDesignDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupPinDesignDto-objects as value to a dart map
  static Map<String, List<GroupPinDesignDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupPinDesignDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupPinDesignDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'badge',
    'bodyColor',
    'imageBorderColor',
    'imageInset',
    'imageZoom',
    'imageAlignmentX',
    'imageAlignmentY',
    'name',
    'outlineColor',
    'outlineWidth',
    'shadow',
    'shape',
    'style',
  };
}
