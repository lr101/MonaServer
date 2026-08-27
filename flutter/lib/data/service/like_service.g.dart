// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserLikeService)
final userLikeServiceProvider = UserLikeServiceFamily._();

final class UserLikeServiceProvider
    extends $AsyncNotifierProvider<UserLikeService, UserLikesDto> {
  UserLikeServiceProvider._({
    required UserLikeServiceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userLikeServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userLikeServiceHash();

  @override
  String toString() {
    return r'userLikeServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  UserLikeService create() => UserLikeService();

  @override
  bool operator ==(Object other) {
    return other is UserLikeServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userLikeServiceHash() => r'374aa3d4c4243fa9960f9aae79860991ba6f3413';

final class UserLikeServiceFamily extends $Family
    with
        $ClassFamilyOverride<
          UserLikeService,
          AsyncValue<UserLikesDto>,
          UserLikesDto,
          FutureOr<UserLikesDto>,
          String
        > {
  UserLikeServiceFamily._()
    : super(
        retry: null,
        name: r'userLikeServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserLikeServiceProvider call(String userId) =>
      UserLikeServiceProvider._(argument: userId, from: this);

  @override
  String toString() => r'userLikeServiceProvider';
}

abstract class _$UserLikeService extends $AsyncNotifier<UserLikesDto> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  FutureOr<UserLikesDto> build(String userId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserLikesDto>, UserLikesDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserLikesDto>, UserLikesDto>,
              AsyncValue<UserLikesDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
