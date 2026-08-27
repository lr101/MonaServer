// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HiddenUserService)
final hiddenUserServiceProvider = HiddenUserServiceProvider._();

final class HiddenUserServiceProvider
    extends $NotifierProvider<HiddenUserService, List<String>> {
  HiddenUserServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiddenUserServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiddenUserServiceHash();

  @$internal
  @override
  HiddenUserService create() => HiddenUserService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$hiddenUserServiceHash() => r'0863d6a3843124b05eb671702041ddf89c9935f6';

abstract class _$HiddenUserService extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(HiddenPostsService)
final hiddenPostsServiceProvider = HiddenPostsServiceProvider._();

final class HiddenPostsServiceProvider
    extends $NotifierProvider<HiddenPostsService, List<String>> {
  HiddenPostsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hiddenPostsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hiddenPostsServiceHash();

  @$internal
  @override
  HiddenPostsService create() => HiddenPostsService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$hiddenPostsServiceHash() =>
    r'0866d069b615508fd00140b418cc92e68d8a27d6';

abstract class _$HiddenPostsService extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
