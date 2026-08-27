// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PinUserService)
final pinUserServiceProvider = PinUserServiceFamily._();

final class PinUserServiceProvider
    extends $StreamNotifierProvider<PinUserService, List<PinEntity>> {
  PinUserServiceProvider._({
    required PinUserServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pinUserServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pinUserServiceHash();

  @override
  String toString() {
    return r'pinUserServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PinUserService create() => PinUserService();

  @override
  bool operator ==(Object other) {
    return other is PinUserServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pinUserServiceHash() => r'3ceeccb0d3448a828b9fd43e59df617481807386';

final class PinUserServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          PinUserService,
          AsyncValue<List<PinEntity>>,
          List<PinEntity>,
          Stream<List<PinEntity>>,
          String
        > {
  PinUserServiceFamily._()
    : super(
        retry: null,
        name: r'pinUserServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PinUserServiceProvider call(String userId) =>
      PinUserServiceProvider._(argument: userId, from: this);

  @override
  String toString() => r'pinUserServiceProvider';
}

abstract class _$PinUserService extends $StreamNotifier<List<PinEntity>> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  Stream<List<PinEntity>> build(String userId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<PinEntity>>, List<PinEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PinEntity>>, List<PinEntity>>,
              AsyncValue<List<PinEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(pinById)
final pinByIdProvider = PinByIdFamily._();

final class PinByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<PinEntity?>,
          PinEntity?,
          Stream<PinEntity?>
        >
    with $FutureModifier<PinEntity?>, $StreamProvider<PinEntity?> {
  PinByIdProvider._({
    required PinByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pinByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pinByIdHash();

  @override
  String toString() {
    return r'pinByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PinEntity?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<PinEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return pinById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PinByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pinByIdHash() => r'b0696d4be4b207ba641594822b20e7500b1417dc';

final class PinByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<PinEntity?>, String> {
  PinByIdFamily._()
    : super(
        retry: null,
        name: r'pinByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PinByIdProvider call(String pinId) =>
      PinByIdProvider._(argument: pinId, from: this);

  @override
  String toString() => r'pinByIdProvider';
}

@ProviderFor(PinGroupServiceUnfiltered)
final pinGroupServiceUnfilteredProvider = PinGroupServiceUnfilteredFamily._();

final class PinGroupServiceUnfilteredProvider
    extends
        $StreamNotifierProvider<PinGroupServiceUnfiltered, List<PinEntity>> {
  PinGroupServiceUnfilteredProvider._({
    required PinGroupServiceUnfilteredFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pinGroupServiceUnfilteredProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pinGroupServiceUnfilteredHash();

  @override
  String toString() {
    return r'pinGroupServiceUnfilteredProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PinGroupServiceUnfiltered create() => PinGroupServiceUnfiltered();

  @override
  bool operator ==(Object other) {
    return other is PinGroupServiceUnfilteredProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pinGroupServiceUnfilteredHash() =>
    r'f0a1441e54da70e5463a8f25e1bb84cd733a85ca';

final class PinGroupServiceUnfilteredFamily extends $Family
    with
        $ClassFamilyOverride<
          PinGroupServiceUnfiltered,
          AsyncValue<List<PinEntity>>,
          List<PinEntity>,
          Stream<List<PinEntity>>,
          String
        > {
  PinGroupServiceUnfilteredFamily._()
    : super(
        retry: null,
        name: r'pinGroupServiceUnfilteredProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PinGroupServiceUnfilteredProvider call(String groupId) =>
      PinGroupServiceUnfilteredProvider._(argument: groupId, from: this);

  @override
  String toString() => r'pinGroupServiceUnfilteredProvider';
}

abstract class _$PinGroupServiceUnfiltered
    extends $StreamNotifier<List<PinEntity>> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  Stream<List<PinEntity>> build(String groupId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<PinEntity>>, List<PinEntity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PinEntity>>, List<PinEntity>>,
              AsyncValue<List<PinEntity>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(pinGroupService)
final pinGroupServiceProvider = PinGroupServiceFamily._();

final class PinGroupServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PinEntity>>,
          List<PinEntity>,
          FutureOr<List<PinEntity>>
        >
    with $FutureModifier<List<PinEntity>>, $FutureProvider<List<PinEntity>> {
  PinGroupServiceProvider._({
    required PinGroupServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'pinGroupServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pinGroupServiceHash();

  @override
  String toString() {
    return r'pinGroupServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PinEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PinEntity>> create(Ref ref) {
    final argument = this.argument as String;
    return pinGroupService(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PinGroupServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pinGroupServiceHash() => r'37003f81c4300d8798348010009c40c471231218';

final class PinGroupServiceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PinEntity>>, String> {
  PinGroupServiceFamily._()
    : super(
        retry: null,
        name: r'pinGroupServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PinGroupServiceProvider call(String groupId) =>
      PinGroupServiceProvider._(argument: groupId, from: this);

  @override
  String toString() => r'pinGroupServiceProvider';
}

@ProviderFor(pinService)
final pinServiceProvider = PinServiceProvider._();

final class PinServiceProvider
    extends $FunctionalProvider<PinService, PinService, PinService>
    with $Provider<PinService> {
  PinServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinServiceHash();

  @$internal
  @override
  $ProviderElement<PinService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinService create(Ref ref) {
    return pinService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinService>(value),
    );
  }
}

String _$pinServiceHash() => r'125f27d3d84ea8c990785b11cf252759f4176706';

@ProviderFor(activatedPinsWithoutLoading)
final activatedPinsWithoutLoadingProvider =
    ActivatedPinsWithoutLoadingProvider._();

final class ActivatedPinsWithoutLoadingProvider
    extends $FunctionalProvider<Set<PinEntity>, Set<PinEntity>, Set<PinEntity>>
    with $Provider<Set<PinEntity>> {
  ActivatedPinsWithoutLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activatedPinsWithoutLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activatedPinsWithoutLoadingHash();

  @$internal
  @override
  $ProviderElement<Set<PinEntity>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<PinEntity> create(Ref ref) {
    return activatedPinsWithoutLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<PinEntity> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<PinEntity>>(value),
    );
  }
}

String _$activatedPinsWithoutLoadingHash() =>
    r'6020447e25360c0eb88bfebca6404816dabdc570';

@ProviderFor(sortedActivatedPins)
final sortedActivatedPinsProvider = SortedActivatedPinsProvider._();

final class SortedActivatedPinsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PinEntity>>,
          AsyncValue<List<PinEntity>>,
          AsyncValue<List<PinEntity>>
        >
    with $Provider<AsyncValue<List<PinEntity>>> {
  SortedActivatedPinsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sortedActivatedPinsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sortedActivatedPinsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<PinEntity>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<PinEntity>> create(Ref ref) {
    return sortedActivatedPins(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<PinEntity>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<PinEntity>>>(value),
    );
  }
}

String _$sortedActivatedPinsHash() =>
    r'e671c94c854044fa18459d6f99eec50ff18053d4';

@ProviderFor(sortedGroupPins)
final sortedGroupPinsProvider = SortedGroupPinsFamily._();

final class SortedGroupPinsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PinEntity>?>,
          List<PinEntity>?,
          FutureOr<List<PinEntity>?>
        >
    with $FutureModifier<List<PinEntity>?>, $FutureProvider<List<PinEntity>?> {
  SortedGroupPinsProvider._({
    required SortedGroupPinsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sortedGroupPinsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sortedGroupPinsHash();

  @override
  String toString() {
    return r'sortedGroupPinsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PinEntity>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PinEntity>?> create(Ref ref) {
    final argument = this.argument as String;
    return sortedGroupPins(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SortedGroupPinsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sortedGroupPinsHash() => r'b50b036f312a2b0383c9e505a14257fd8cdecfbf';

final class SortedGroupPinsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PinEntity>?>, String> {
  SortedGroupPinsFamily._()
    : super(
        retry: null,
        name: r'sortedGroupPinsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SortedGroupPinsProvider call(String groupId) =>
      SortedGroupPinsProvider._(argument: groupId, from: this);

  @override
  String toString() => r'sortedGroupPinsProvider';
}
