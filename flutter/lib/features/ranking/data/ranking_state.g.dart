// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RankingGid)
final rankingGidProvider = RankingGidProvider._();

final class RankingGidProvider
    extends $NotifierProvider<RankingGid, RankingSearchDtoInner?> {
  RankingGidProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rankingGidProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rankingGidHash();

  @$internal
  @override
  RankingGid create() => RankingGid();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RankingSearchDtoInner? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RankingSearchDtoInner?>(value),
    );
  }
}

String _$rankingGidHash() => r'b97a0c2715209e17aca9908bd67d31323a9a3506';

abstract class _$RankingGid extends $Notifier<RankingSearchDtoInner?> {
  RankingSearchDtoInner? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<RankingSearchDtoInner?, RankingSearchDtoInner?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RankingSearchDtoInner?, RankingSearchDtoInner?>,
              RankingSearchDtoInner?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RankingSearch)
final rankingSearchProvider = RankingSearchProvider._();

final class RankingSearchProvider
    extends $AsyncNotifierProvider<RankingSearch, List<RankingSearchDtoInner>> {
  RankingSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rankingSearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rankingSearchHash();

  @$internal
  @override
  RankingSearch create() => RankingSearch();
}

String _$rankingSearchHash() => r'160b6ac38994aeda2cabe3c1f7808fcb71351706';

abstract class _$RankingSearch
    extends $AsyncNotifier<List<RankingSearchDtoInner>> {
  FutureOr<List<RankingSearchDtoInner>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RankingSearchDtoInner>>,
              List<RankingSearchDtoInner>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RankingSearchDtoInner>>,
                List<RankingSearchDtoInner>
              >,
              AsyncValue<List<RankingSearchDtoInner>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RankingTimeSelector)
final rankingTimeSelectorProvider = RankingTimeSelectorProvider._();

final class RankingTimeSelectorProvider
    extends $NotifierProvider<RankingTimeSelector, int> {
  RankingTimeSelectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rankingTimeSelectorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rankingTimeSelectorHash();

  @$internal
  @override
  RankingTimeSelector create() => RankingTimeSelector();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$rankingTimeSelectorHash() =>
    r'1f05a6bea0fa72649132ceee63bd4a122e852f4d';

abstract class _$RankingTimeSelector extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
