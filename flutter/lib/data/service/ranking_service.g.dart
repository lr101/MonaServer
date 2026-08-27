// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrentUserTopRanking)
final currentUserTopRankingProvider = CurrentUserTopRankingProvider._();

final class CurrentUserTopRankingProvider
    extends
        $AsyncNotifierProvider<
          CurrentUserTopRanking,
          List<UserRankingDtoInner>?
        > {
  CurrentUserTopRankingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserTopRankingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserTopRankingHash();

  @$internal
  @override
  CurrentUserTopRanking create() => CurrentUserTopRanking();
}

String _$currentUserTopRankingHash() =>
    r'2df4e7c6b0cd4fc635bc0ba7eaf2f980a724a2cf';

abstract class _$CurrentUserTopRanking
    extends $AsyncNotifier<List<UserRankingDtoInner>?> {
  FutureOr<List<UserRankingDtoInner>?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<UserRankingDtoInner>?>,
              List<UserRankingDtoInner>?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<UserRankingDtoInner>?>,
                List<UserRankingDtoInner>?
              >,
              AsyncValue<List<UserRankingDtoInner>?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
