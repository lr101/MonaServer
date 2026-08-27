// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_json_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(zoomGeoLevel)
final zoomGeoLevelProvider = ZoomGeoLevelProvider._();

final class ZoomGeoLevelProvider extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  ZoomGeoLevelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoomGeoLevelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoomGeoLevelHash();

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    return zoomGeoLevel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$zoomGeoLevelHash() => r'02c843dd153e196be180e495f78910f26ffcc17a';

@ProviderFor(zoomGid)
final zoomGidProvider = ZoomGidProvider._();

final class ZoomGidProvider
    extends
        $FunctionalProvider<
          (String?, String?),
          (String?, String?),
          (String?, String?)
        >
    with $Provider<(String?, String?)> {
  ZoomGidProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoomGidProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoomGidHash();

  @$internal
  @override
  $ProviderElement<(String?, String?)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  (String?, String?) create(Ref ref) {
    return zoomGid(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue((String?, String?) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<(String?, String?)>(value),
    );
  }
}

String _$zoomGidHash() => r'63e2ba1434ffa4f2807b245a03d840c9e835a579';

@ProviderFor(groupRanking)
final groupRankingProvider = GroupRankingFamily._();

final class GroupRankingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GroupRankingDtoInner>?>,
          List<GroupRankingDtoInner>?,
          FutureOr<List<GroupRankingDtoInner>?>
        >
    with
        $FutureModifier<List<GroupRankingDtoInner>?>,
        $FutureProvider<List<GroupRankingDtoInner>?> {
  GroupRankingProvider._({
    required GroupRankingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupRankingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupRankingHash();

  @override
  String toString() {
    return r'groupRankingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<GroupRankingDtoInner>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GroupRankingDtoInner>?> create(Ref ref) {
    final argument = this.argument as String;
    return groupRanking(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupRankingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupRankingHash() => r'42a8289ab65000e9f861e4cdaa6978e417d9a098';

final class GroupRankingFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<GroupRankingDtoInner>?>,
          String
        > {
  GroupRankingFamily._()
    : super(
        retry: null,
        name: r'groupRankingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupRankingProvider call(String gid) =>
      GroupRankingProvider._(argument: gid, from: this);

  @override
  String toString() => r'groupRankingProvider';
}

@ProviderFor(userRanking)
final userRankingProvider = UserRankingFamily._();

final class UserRankingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UserRankingDtoInner>?>,
          List<UserRankingDtoInner>?,
          FutureOr<List<UserRankingDtoInner>?>
        >
    with
        $FutureModifier<List<UserRankingDtoInner>?>,
        $FutureProvider<List<UserRankingDtoInner>?> {
  UserRankingProvider._({
    required UserRankingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userRankingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userRankingHash();

  @override
  String toString() {
    return r'userRankingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<UserRankingDtoInner>?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UserRankingDtoInner>?> create(Ref ref) {
    final argument = this.argument as String;
    return userRanking(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserRankingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userRankingHash() => r'4cae3645485f234acde3df80e53fc4816109cd24';

final class UserRankingFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<UserRankingDtoInner>?>,
          String
        > {
  UserRankingFamily._()
    : super(
        retry: null,
        name: r'userRankingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserRankingProvider call(String gid) =>
      UserRankingProvider._(argument: gid, from: this);

  @override
  String toString() => r'userRankingProvider';
}
