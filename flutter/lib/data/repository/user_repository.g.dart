// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userRepository)
final userRepositoryProvider = UserRepositoryProvider._();

final class UserRepositoryProvider
    extends
        $FunctionalProvider<IUserRepository, IUserRepository, IUserRepository>
    with $Provider<IUserRepository> {
  UserRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRepositoryHash();

  @$internal
  @override
  $ProviderElement<IUserRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IUserRepository create(Ref ref) {
    return userRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IUserRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IUserRepository>(value),
    );
  }
}

String _$userRepositoryHash() => r'108edef4a3a77387fdc984f764caeb3a256c0f70';

@ProviderFor(userLikeRepository)
final userLikeRepositoryProvider = UserLikeRepositoryProvider._();

final class UserLikeRepositoryProvider
    extends
        $FunctionalProvider<
          IUserLikeRepository,
          IUserLikeRepository,
          IUserLikeRepository
        >
    with $Provider<IUserLikeRepository> {
  UserLikeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userLikeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userLikeRepositoryHash();

  @$internal
  @override
  $ProviderElement<IUserLikeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IUserLikeRepository create(Ref ref) {
    return userLikeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IUserLikeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IUserLikeRepository>(value),
    );
  }
}

String _$userLikeRepositoryHash() =>
    r'c1131f4c3b7f9731cdf4b6c2b74e69761851a2e6';
