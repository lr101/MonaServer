//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminReportStatus {
  /// Instantiate a new enum with the provided [value].
  const AdminReportStatus._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const open = AdminReportStatus._(r'open');
  static const resolved = AdminReportStatus._(r'resolved');
  static const dismissed = AdminReportStatus._(r'dismissed');

  /// List of all possible values in this [enum][AdminReportStatus].
  static const values = <AdminReportStatus>[
    open,
    resolved,
    dismissed,
  ];

  static AdminReportStatus? fromJson(dynamic value) => AdminReportStatusTypeTransformer().decode(value);

  static List<AdminReportStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminReportStatus] to String,
/// and [decode] dynamic data back to [AdminReportStatus].
class AdminReportStatusTypeTransformer {
  factory AdminReportStatusTypeTransformer() => _instance ??= const AdminReportStatusTypeTransformer._();

  const AdminReportStatusTypeTransformer._();

  String encode(AdminReportStatus data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminReportStatus.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminReportStatus? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'open': return AdminReportStatus.open;
        case r'resolved': return AdminReportStatus.resolved;
        case r'dismissed': return AdminReportStatus.dismissed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminReportStatusTypeTransformer] instance.
  static AdminReportStatusTypeTransformer? _instance;
}

