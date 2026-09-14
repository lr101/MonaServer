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

String _$syncingServiceHash() => r'4a91b4bf5c0e6678aacc3080ee541d7953d07ac6';

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
