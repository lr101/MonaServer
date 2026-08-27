// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_data_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GlobalDataService)
final globalDataServiceProvider = GlobalDataServiceProvider._();

final class GlobalDataServiceProvider
    extends $NotifierProvider<GlobalDataService, GlobalDataDto> {
  GlobalDataServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalDataServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalDataServiceHash();

  @$internal
  @override
  GlobalDataService create() => GlobalDataService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalDataDto value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalDataDto>(value),
    );
  }
}

String _$globalDataServiceHash() => r'aceb2701ab9f36ea7d36b30bf542abe1bd53daf3';

abstract class _$GlobalDataService extends $Notifier<GlobalDataDto> {
  GlobalDataDto build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GlobalDataDto, GlobalDataDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GlobalDataDto, GlobalDataDto>,
              GlobalDataDto,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AuthService)
final authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends $AsyncNotifierProvider<AuthService, bool> {
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  AuthService create() => AuthService();
}

String _$authServiceHash() => r'3d03c9c95d823fab4fa4a9475c3befc344851028';

abstract class _$AuthService extends $AsyncNotifier<bool> {
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

@ProviderFor(userId)
final userIdProvider = UserIdProvider._();

final class UserIdProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  UserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return userId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$userIdHash() => r'24095f82a714ab05f319cce80838bae05c12d114';

@ProviderFor(CameraTorch)
final cameraTorchProvider = CameraTorchProvider._();

final class CameraTorchProvider extends $NotifierProvider<CameraTorch, bool> {
  CameraTorchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraTorchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraTorchHash();

  @$internal
  @override
  CameraTorch create() => CameraTorch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cameraTorchHash() => r'd9b867808565232d7ea3ccb93b3f588211414af4';

abstract class _$CameraTorch extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LastSeen)
final lastSeenProvider = LastSeenFamily._();

final class LastSeenProvider extends $NotifierProvider<LastSeen, DateTime?> {
  LastSeenProvider._({
    required LastSeenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lastSeenProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lastSeenHash();

  @override
  String toString() {
    return r'lastSeenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LastSeen create() => LastSeen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LastSeenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lastSeenHash() => r'b4f24d4f840100f24821ac2ea1675825cae33292';

final class LastSeenFamily extends $Family
    with
        $ClassFamilyOverride<
          LastSeen,
          DateTime?,
          DateTime?,
          DateTime?,
          String
        > {
  LastSeenFamily._()
    : super(
        retry: null,
        name: r'lastSeenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LastSeenProvider call(String key) =>
      LastSeenProvider._(argument: key, from: this);

  @override
  String toString() => r'lastSeenProvider';
}

abstract class _$LastSeen extends $Notifier<DateTime?> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  DateTime? build(String key);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime?, DateTime?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime?, DateTime?>,
              DateTime?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(lastKnownLocation)
final lastKnownLocationProvider = LastKnownLocationProvider._();

final class LastKnownLocationProvider
    extends $FunctionalProvider<LatLng, LatLng, LatLng>
    with $Provider<LatLng> {
  LastKnownLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastKnownLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastKnownLocationHash();

  @$internal
  @override
  $ProviderElement<LatLng> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LatLng create(Ref ref) {
    return lastKnownLocation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LatLng value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LatLng>(value),
    );
  }
}

String _$lastKnownLocationHash() => r'32bf99245b9bc078cb9ab20675d6db2f5b6f0191';
