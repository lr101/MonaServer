// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'global_data_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(secureStorage)
final secureStorageProvider = SecureStorageProvider._();

final class SecureStorageProvider
    extends $FunctionalProvider<ISecureStorage, ISecureStorage, ISecureStorage>
    with $Provider<ISecureStorage> {
  SecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureStorageHash();

  @$internal
  @override
  $ProviderElement<ISecureStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISecureStorage create(Ref ref) {
    return secureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISecureStorage>(value),
    );
  }
}

String _$secureStorageHash() => r'b49a379497b072d483b904c0e7f38fa488dfb9a5';

@ProviderFor(globalDataRepository)
final globalDataRepositoryProvider = GlobalDataRepositoryProvider._();

final class GlobalDataRepositoryProvider
    extends
        $FunctionalProvider<
          GlobalDataRepository,
          GlobalDataRepository,
          GlobalDataRepository
        >
    with $Provider<GlobalDataRepository> {
  GlobalDataRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalDataRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalDataRepositoryHash();

  @$internal
  @override
  $ProviderElement<GlobalDataRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GlobalDataRepository create(Ref ref) {
    return globalDataRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalDataRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalDataRepository>(value),
    );
  }
}

String _$globalDataRepositoryHash() =>
    r'52018c90eb3d4d4a9b0367097eaa4aa0695da2f0';

@ProviderFor(globalDataOnce)
final globalDataOnceProvider = GlobalDataOnceProvider._();

final class GlobalDataOnceProvider
    extends $FunctionalProvider<GlobalDataDto, GlobalDataDto, GlobalDataDto>
    with $Provider<GlobalDataDto> {
  GlobalDataOnceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalDataOnceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalDataOnceHash();

  @$internal
  @override
  $ProviderElement<GlobalDataDto> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GlobalDataDto create(Ref ref) {
    return globalDataOnce(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalDataDto value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalDataDto>(value),
    );
  }
}

String _$globalDataOnceHash() => r'94d894761acf917a095162ba6b7f044cef140fee';

@ProviderFor(currentUserOnce)
final currentUserOnceProvider = CurrentUserOnceProvider._();

final class CurrentUserOnceProvider
    extends $FunctionalProvider<CurrentUserDto, CurrentUserDto, CurrentUserDto>
    with $Provider<CurrentUserDto> {
  CurrentUserOnceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserOnceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserOnceHash();

  @$internal
  @override
  $ProviderElement<CurrentUserDto> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CurrentUserDto create(Ref ref) {
    return currentUserOnce(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurrentUserDto value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurrentUserDto>(value),
    );
  }
}

String _$currentUserOnceHash() => r'6e4d8bf13ea35b7f3d7ab3c08a4dfeb35e59ed6f';

@ProviderFor(flutterSecureStorage)
final flutterSecureStorageProvider = FlutterSecureStorageProvider._();

final class FlutterSecureStorageProvider
    extends $FunctionalProvider<ISecureStorage, ISecureStorage, ISecureStorage>
    with $Provider<ISecureStorage> {
  FlutterSecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flutterSecureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flutterSecureStorageHash();

  @$internal
  @override
  $ProviderElement<ISecureStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISecureStorage create(Ref ref) {
    return flutterSecureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISecureStorage>(value),
    );
  }
}

String _$flutterSecureStorageHash() =>
    r'3338f964f8b42912c6f2a72b8de29d098ab5feec';
