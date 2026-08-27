// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationState)
final notificationStateProvider = NotificationStateProvider._();

final class NotificationStateProvider
    extends $AsyncNotifierProvider<NotificationState, bool> {
  NotificationStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationStateHash();

  @$internal
  @override
  NotificationState create() => NotificationState();
}

String _$notificationStateHash() => r'c9fff555869543f4e1be115381540d18e449fe4b';

abstract class _$NotificationState extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
