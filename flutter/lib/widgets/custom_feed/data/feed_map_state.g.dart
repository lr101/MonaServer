// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_map_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedMapState)
final feedMapStateProvider = FeedMapStateFamily._();

final class FeedMapStateProvider extends $NotifierProvider<FeedMapState, bool> {
  FeedMapStateProvider._({
    required FeedMapStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'feedMapStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$feedMapStateHash();

  @override
  String toString() {
    return r'feedMapStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FeedMapState create() => FeedMapState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FeedMapStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$feedMapStateHash() => r'a7d42ddf7eb5756f0bc5d2e604d8a367c485af93';

final class FeedMapStateFamily extends $Family
    with $ClassFamilyOverride<FeedMapState, bool, bool, bool, String> {
  FeedMapStateFamily._()
    : super(
        retry: null,
        name: r'feedMapStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FeedMapStateProvider call(String pinId) =>
      FeedMapStateProvider._(argument: pinId, from: this);

  @override
  String toString() => r'feedMapStateProvider';
}

abstract class _$FeedMapState extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get pinId => _$args;

  bool build(String pinId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
