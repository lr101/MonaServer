// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openapi_config.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OpenApiConfig)
final openApiConfigProvider = OpenApiConfigProvider._();

final class OpenApiConfigProvider
    extends $NotifierProvider<OpenApiConfig, ApiClient> {
  OpenApiConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openApiConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openApiConfigHash();

  @$internal
  @override
  OpenApiConfig create() => OpenApiConfig();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$openApiConfigHash() => r'787ba07edc4f2681137316a5288e4e5543329bb9';

abstract class _$OpenApiConfig extends $Notifier<ApiClient> {
  ApiClient build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ApiClient, ApiClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ApiClient, ApiClient>,
              ApiClient,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(pinApi)
final pinApiProvider = PinApiProvider._();

final class PinApiProvider
    extends $FunctionalProvider<PinsApi, PinsApi, PinsApi>
    with $Provider<PinsApi> {
  PinApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinApiHash();

  @$internal
  @override
  $ProviderElement<PinsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinsApi create(Ref ref) {
    return pinApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinsApi>(value),
    );
  }
}

String _$pinApiHash() => r'63694a72551560399ef7f0d6229f527a73d80b5e';

@ProviderFor(groupApi)
final groupApiProvider = GroupApiProvider._();

final class GroupApiProvider
    extends $FunctionalProvider<GroupsApi, GroupsApi, GroupsApi>
    with $Provider<GroupsApi> {
  GroupApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupApiHash();

  @$internal
  @override
  $ProviderElement<GroupsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GroupsApi create(Ref ref) {
    return groupApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupsApi>(value),
    );
  }
}

String _$groupApiHash() => r'b1af627b8fcabd51b34e5256d6b930062f5b261c';

@ProviderFor(userApi)
final userApiProvider = UserApiProvider._();

final class UserApiProvider
    extends $FunctionalProvider<UsersApi, UsersApi, UsersApi>
    with $Provider<UsersApi> {
  UserApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userApiHash();

  @$internal
  @override
  $ProviderElement<UsersApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UsersApi create(Ref ref) {
    return userApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsersApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsersApi>(value),
    );
  }
}

String _$userApiHash() => r'625731af7b01225bbb8d6330930b0d8285a24028';

@ProviderFor(authApi)
final authApiProvider = AuthApiProvider._();

final class AuthApiProvider
    extends $FunctionalProvider<AuthApi, AuthApi, AuthApi>
    with $Provider<AuthApi> {
  AuthApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authApiHash();

  @$internal
  @override
  $ProviderElement<AuthApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthApi create(Ref ref) {
    return authApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthApi>(value),
    );
  }
}

String _$authApiHash() => r'a3560de16373c563da2b9bae56c13bd41096a968';

@ProviderFor(memberApi)
final memberApiProvider = MemberApiProvider._();

final class MemberApiProvider
    extends $FunctionalProvider<MembersApi, MembersApi, MembersApi>
    with $Provider<MembersApi> {
  MemberApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberApiHash();

  @$internal
  @override
  $ProviderElement<MembersApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MembersApi create(Ref ref) {
    return memberApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MembersApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MembersApi>(value),
    );
  }
}

String _$memberApiHash() => r'62285c719ed5f6bf488db20c93b66be8c6c54acb';

@ProviderFor(reportApi)
final reportApiProvider = ReportApiProvider._();

final class ReportApiProvider
    extends $FunctionalProvider<ReportApi, ReportApi, ReportApi>
    with $Provider<ReportApi> {
  ReportApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportApiHash();

  @$internal
  @override
  $ProviderElement<ReportApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportApi create(Ref ref) {
    return reportApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportApi>(value),
    );
  }
}

String _$reportApiHash() => r'7d280e3391bffc8f5866c96c1c7b288799b7fc96';

@ProviderFor(likeApi)
final likeApiProvider = LikeApiProvider._();

final class LikeApiProvider
    extends $FunctionalProvider<LikesApi, LikesApi, LikesApi>
    with $Provider<LikesApi> {
  LikeApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likeApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likeApiHash();

  @$internal
  @override
  $ProviderElement<LikesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LikesApi create(Ref ref) {
    return likeApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LikesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LikesApi>(value),
    );
  }
}

String _$likeApiHash() => r'5095098e8e98d14190505cce9fad7482cb1d5bca';

@ProviderFor(rankingApi)
final rankingApiProvider = RankingApiProvider._();

final class RankingApiProvider
    extends $FunctionalProvider<RankingApi, RankingApi, RankingApi>
    with $Provider<RankingApi> {
  RankingApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rankingApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rankingApiHash();

  @$internal
  @override
  $ProviderElement<RankingApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RankingApi create(Ref ref) {
    return rankingApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RankingApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RankingApi>(value),
    );
  }
}

String _$rankingApiHash() => r'275731b01ad88a4c8263f0a74cdc0f67effe9b40';
