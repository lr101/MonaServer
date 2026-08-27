// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'syncing_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SyncingService)
final syncingServiceProvider = SyncingServiceProvider._();

final class SyncingServiceProvider
    extends $NotifierProvider<SyncingService, SyncState> {
  SyncingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncingServiceHash();

  @$internal
  @override
  SyncingService create() => SyncingService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncingServiceHash() => r'db21f137377b8b9e6dfa0eca6a14a3ef4ae631e3';

abstract class _$SyncingService extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
