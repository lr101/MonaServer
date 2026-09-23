//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminCampaignChannel {
  /// Instantiate a new enum with the provided [value].
  const AdminCampaignChannel._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const email = AdminCampaignChannel._(r'email');
  static const push = AdminCampaignChannel._(r'push');

  /// List of all possible values in this [enum][AdminCampaignChannel].
  static const values = <AdminCampaignChannel>[
    email,
    push,
  ];

  static AdminCampaignChannel? fromJson(dynamic value) => AdminCampaignChannelTypeTransformer().decode(value);

  static List<AdminCampaignChannel> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminCampaignChannel>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminCampaignChannel.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminCampaignChannel] to String,
/// and [decode] dynamic data back to [AdminCampaignChannel].
class AdminCampaignChannelTypeTransformer {
  factory AdminCampaignChannelTypeTransformer() => _instance ??= const AdminCampaignChannelTypeTransformer._();

  const AdminCampaignChannelTypeTransformer._();

  String encode(AdminCampaignChannel data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminCampaignChannel.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminCampaignChannel? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'email': return AdminCampaignChannel.email;
        case r'push': return AdminCampaignChannel.push;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminCampaignChannelTypeTransformer] instance.
  static AdminCampaignChannelTypeTransformer? _instance;
}
