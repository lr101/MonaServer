//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminJobStatus {
  /// Instantiate a new enum with the provided [value].
  const AdminJobStatus._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AdminJobStatus._(r'pending');
  static const running = AdminJobStatus._(r'running');
  static const completed = AdminJobStatus._(r'completed');
  static const completedWithErrors = AdminJobStatus._(r'completed_with_errors');
  static const paused = AdminJobStatus._(r'paused');
  static const cancelled = AdminJobStatus._(r'cancelled');

  /// List of all possible values in this [enum][AdminJobStatus].
  static const values = <AdminJobStatus>[
    pending,
    running,
    completed,
    completedWithErrors,
    paused,
    cancelled,
  ];

  static AdminJobStatus? fromJson(dynamic value) => AdminJobStatusTypeTransformer().decode(value);

  static List<AdminJobStatus> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminJobStatus>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminJobStatus.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminJobStatus] to String,
/// and [decode] dynamic data back to [AdminJobStatus].
class AdminJobStatusTypeTransformer {
  factory AdminJobStatusTypeTransformer() => _instance ??= const AdminJobStatusTypeTransformer._();

  const AdminJobStatusTypeTransformer._();

  String encode(AdminJobStatus data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminJobStatus.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminJobStatus? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AdminJobStatus.pending;
        case r'running': return AdminJobStatus.running;
        case r'completed': return AdminJobStatus.completed;
        case r'completed_with_errors': return AdminJobStatus.completedWithErrors;
        case r'paused': return AdminJobStatus.paused;
        case r'cancelled': return AdminJobStatus.cancelled;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminJobStatusTypeTransformer] instance.
  static AdminJobStatusTypeTransformer? _instance;
}

