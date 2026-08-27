// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_pins_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userPinsRepository)
final userPinsRepositoryProvider = UserPinsRepositoryProvider._();

final class UserPinsRepositoryProvider
    extends
        $FunctionalProvider<
          IUserPinsRepository,
          IUserPinsRepository,
          IUserPinsRepository
        >
    with $Provider<IUserPinsRepository> {
  UserPinsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userPinsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userPinsRepositoryHash();

  @$internal
  @override
  $ProviderElement<IUserPinsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IUserPinsRepository create(Ref ref) {
    return userPinsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IUserPinsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IUserPinsRepository>(value),
    );
  }
}

String _$userPinsRepositoryHash() =>
    r'7035270f6fbd748bd0d7baff6ad87d0bdb4239ab';
