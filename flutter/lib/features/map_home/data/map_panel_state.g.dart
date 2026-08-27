// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_panel_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MapPanelState)
final mapPanelStateProvider = MapPanelStateProvider._();

final class MapPanelStateProvider
    extends $NotifierProvider<MapPanelState, bool> {
  MapPanelStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapPanelStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapPanelStateHash();

  @$internal
  @override
  MapPanelState create() => MapPanelState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$mapPanelStateHash() => r'd2d9ae3943f5158a973e4abe611a4c16969e6984';

abstract class _$MapPanelState extends $Notifier<bool> {
  bool build();
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
    return element.handleCreate(ref, build);
  }
}
