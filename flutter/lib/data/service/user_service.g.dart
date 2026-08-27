// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserService)
final userServiceProvider = UserServiceFamily._();

final class UserServiceProvider
    extends $StreamNotifierProvider<UserService, UserEntity?> {
  UserServiceProvider._({
    required UserServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userServiceHash();

  @override
  String toString() {
    return r'userServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UserService create() => UserService();

  @override
  bool operator ==(Object other) {
    return other is UserServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userServiceHash() => r'e9ff2e99560088b17c8a2d9ffa8b649d15d9c76e';

final class UserServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          UserService,
          AsyncValue<UserEntity?>,
          UserEntity?,
          Stream<UserEntity?>,
          String
        > {
  UserServiceFamily._()
    : super(
        retry: null,
        name: r'userServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserServiceProvider call(String userId) =>
      UserServiceProvider._(argument: userId, from: this);

  @override
  String toString() => r'userServiceProvider';
}

abstract class _$UserService extends $StreamNotifier<UserEntity?> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  Stream<UserEntity?> build(String userId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserEntity?>, UserEntity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserEntity?>, UserEntity?>,
              AsyncValue<UserEntity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(userByIdUsername)
final userByIdUsernameProvider = UserByIdUsernameFamily._();

final class UserByIdUsernameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  UserByIdUsernameProvider._({
    required UserByIdUsernameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userByIdUsernameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userByIdUsernameHash();

  @override
  String toString() {
    return r'userByIdUsernameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return userByIdUsername(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserByIdUsernameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userByIdUsernameHash() => r'27fbfa2239f745e103be782eb3049d83e5b6e14e';

final class UserByIdUsernameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  UserByIdUsernameFamily._()
    : super(
        retry: null,
        name: r'userByIdUsernameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserByIdUsernameProvider call(String userId) =>
      UserByIdUsernameProvider._(argument: userId, from: this);

  @override
  String toString() => r'userByIdUsernameProvider';
}

@ProviderFor(userByIdSelectedBatch)
final userByIdSelectedBatchProvider = UserByIdSelectedBatchFamily._();

final class UserByIdSelectedBatchProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  UserByIdSelectedBatchProvider._({
    required UserByIdSelectedBatchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userByIdSelectedBatchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userByIdSelectedBatchHash();

  @override
  String toString() {
    return r'userByIdSelectedBatchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as String;
    return userByIdSelectedBatch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserByIdSelectedBatchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userByIdSelectedBatchHash() =>
    r'1bf0914796a3e386b1614785a42300ea62ac0e1c';

final class UserByIdSelectedBatchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, String> {
  UserByIdSelectedBatchFamily._()
    : super(
        retry: null,
        name: r'userByIdSelectedBatchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserByIdSelectedBatchProvider call(String userId) =>
      UserByIdSelectedBatchProvider._(argument: userId, from: this);

  @override
  String toString() => r'userByIdSelectedBatchProvider';
}

@ProviderFor(userByIdDescription)
final userByIdDescriptionProvider = UserByIdDescriptionFamily._();

final class UserByIdDescriptionProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  UserByIdDescriptionProvider._({
    required UserByIdDescriptionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userByIdDescriptionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userByIdDescriptionHash();

  @override
  String toString() {
    return r'userByIdDescriptionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return userByIdDescription(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserByIdDescriptionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userByIdDescriptionHash() =>
    r'807d617e46eed0e31274313a7f979efaea71c64e';

final class UserByIdDescriptionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  UserByIdDescriptionFamily._()
    : super(
        retry: null,
        name: r'userByIdDescriptionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserByIdDescriptionProvider call(String userId) =>
      UserByIdDescriptionProvider._(argument: userId, from: this);

  @override
  String toString() => r'userByIdDescriptionProvider';
}

@ProviderFor(userByIdBestSeason)
final userByIdBestSeasonProvider = UserByIdBestSeasonFamily._();

final class UserByIdBestSeasonProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeasonEntity?>,
          SeasonEntity?,
          FutureOr<SeasonEntity?>
        >
    with $FutureModifier<SeasonEntity?>, $FutureProvider<SeasonEntity?> {
  UserByIdBestSeasonProvider._({
    required UserByIdBestSeasonFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userByIdBestSeasonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userByIdBestSeasonHash();

  @override
  String toString() {
    return r'userByIdBestSeasonProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SeasonEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeasonEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return userByIdBestSeason(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserByIdBestSeasonProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userByIdBestSeasonHash() =>
    r'4c63d7313024bb3ff3a92e5cfd8764cd9c4e7a77';

final class UserByIdBestSeasonFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SeasonEntity?>, String> {
  UserByIdBestSeasonFamily._()
    : super(
        retry: null,
        name: r'userByIdBestSeasonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserByIdBestSeasonProvider call(String userId) =>
      UserByIdBestSeasonProvider._(argument: userId, from: this);

  @override
  String toString() => r'userByIdBestSeasonProvider';
}

@ProviderFor(currentUser)
final currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserEntity?>,
          UserEntity?,
          FutureOr<UserEntity?>
        >
    with $FutureModifier<UserEntity?>, $FutureProvider<UserEntity?> {
  CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $FutureProviderElement<UserEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserEntity?> create(Ref ref) {
    return currentUser(ref);
  }
}

String _$currentUserHash() => r'eab8608f49497a11342ee6ca703b94e5ca4bc34f';
