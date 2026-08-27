// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MapStates)
final mapStatesProvider = MapStatesProvider._();

final class MapStatesProvider extends $NotifierProvider<MapStates, MapState> {
  MapStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapStatesHash();

  @$internal
  @override
  MapStates create() => MapStates();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapState>(value),
    );
  }
}

String _$mapStatesHash() => r'026eeb518042f9823570dd45c228554235bc21c9';

abstract class _$MapStates extends $Notifier<MapState> {
  MapState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MapState, MapState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MapState, MapState>,
              MapState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(currentLocation)
final currentLocationProvider = CurrentLocationProvider._();

final class CurrentLocationProvider
    extends
        $FunctionalProvider<AsyncValue<Position>, Position, Stream<Position>>
    with $FutureModifier<Position>, $StreamProvider<Position> {
  CurrentLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentLocationHash();

  @$internal
  @override
  $StreamProviderElement<Position> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Position> create(Ref ref) {
    return currentLocation(ref);
  }
}

String _$currentLocationHash() => r'd5de2759b915419e2ede395268475714aae4e37a';

@ProviderFor(MapZoomLevel)
final mapZoomLevelProvider = MapZoomLevelProvider._();

final class MapZoomLevelProvider
    extends $NotifierProvider<MapZoomLevel, double> {
  MapZoomLevelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapZoomLevelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapZoomLevelHash();

  @$internal
  @override
  MapZoomLevel create() => MapZoomLevel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$mapZoomLevelHash() => r'c9def2bf637381bd76c5843eaea03962db319b40';

abstract class _$MapZoomLevel extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
