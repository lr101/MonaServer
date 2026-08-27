// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_order_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupOrderService)
final groupOrderServiceProvider = GroupOrderServiceProvider._();

final class GroupOrderServiceProvider
    extends $NotifierProvider<GroupOrderService, List<String>> {
  GroupOrderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupOrderServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupOrderServiceHash();

  @$internal
  @override
  GroupOrderService create() => GroupOrderService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$groupOrderServiceHash() => r'2790ab3a56c80bb1f4c415e95c0d37481d115ba6';

abstract class _$GroupOrderService extends $Notifier<List<String>> {
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

@ProviderFor(roundGroupId)
final roundGroupIdProvider = RoundGroupIdProvider._();

final class RoundGroupIdProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  RoundGroupIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roundGroupIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roundGroupIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return roundGroupId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$roundGroupIdHash() => r'dd926cf843566b1db3f10083769172177a6cd74e';

@ProviderFor(GroupActiveService)
final groupActiveServiceProvider = GroupActiveServiceProvider._();

final class GroupActiveServiceProvider
    extends $NotifierProvider<GroupActiveService, List<String>> {
  GroupActiveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupActiveServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupActiveServiceHash();

  @$internal
  @override
  GroupActiveService create() => GroupActiveService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$groupActiveServiceHash() =>
    r'c0d5841b812c687a6e41987bfce5b341ebdc3476';

abstract class _$GroupActiveService extends $Notifier<List<String>> {
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
