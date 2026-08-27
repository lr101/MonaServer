//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserUpdateDto {
  /// Returns a new [UserUpdateDto] instance.
  UserUpdateDto({
    this.email,
    this.password,
    this.image,
    this.username,
    this.description,
    this.selectedBatch,
    this.messagingToken,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? email;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? password;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? image;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? username;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? description;

  int? selectedBatch;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? messagingToken;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserUpdateDto &&
    other.email == email &&
    other.password == password &&
    other.image == image &&
    other.username == username &&
    other.description == description &&
    other.selectedBatch == selectedBatch &&
    other.messagingToken == messagingToken;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (email == null ? 0 : email!.hashCode) +
    (password == null ? 0 : password!.hashCode) +
    (image == null ? 0 : image!.hashCode) +
    (username == null ? 0 : username!.hashCode) +
    (description == null ? 0 : description!.hashCode) +
    (selectedBatch == null ? 0 : selectedBatch!.hashCode) +
    (messagingToken == null ? 0 : messagingToken!.hashCode);

  @override
  String toString() => 'UserUpdateDto[email=$email, password=$password, image=$image, username=$username, description=$description, selectedBatch=$selectedBatch, messagingToken=$messagingToken]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.password != null) {
      json[r'password'] = this.password;
    } else {
      json[r'password'] = null;
    }
    if (this.image != null) {
      json[r'image'] = this.image;
    } else {
      json[r'image'] = null;
    }
    if (this.username != null) {
      json[r'username'] = this.username;
    } else {
      json[r'username'] = null;
    }
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    if (this.selectedBatch != null) {
      json[r'selectedBatch'] = this.selectedBatch;
    } else {
      json[r'selectedBatch'] = null;
    }
    if (this.messagingToken != null) {
      json[r'messagingToken'] = this.messagingToken;
    } else {
      json[r'messagingToken'] = null;
    }
    return json;
  }

  /// Returns a new [UserUpdateDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserUpdateDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserUpdateDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserUpdateDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserUpdateDto(
        email: mapValueOfType<String>(json, r'email'),
        password: mapValueOfType<String>(json, r'password'),
        image: mapValueOfType<String>(json, r'image'),
        username: mapValueOfType<String>(json, r'username'),
        description: mapValueOfType<String>(json, r'description'),
        selectedBatch: mapValueOfType<int>(json, r'selectedBatch'),
        messagingToken: mapValueOfType<String>(json, r'messagingToken'),
      );
    }
    return null;
  }

  static List<UserUpdateDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserUpdateDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserUpdateDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserUpdateDto> mapFromJson(dynamic json) {
    final map = <String, UserUpdateDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserUpdateDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserUpdateDto-objects as value to a dart map
  static Map<String, List<UserUpdateDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserUpdateDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserUpdateDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

