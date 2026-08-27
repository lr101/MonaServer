// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geojson_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DistrictService)
final districtServiceProvider = DistrictServiceProvider._();

final class DistrictServiceProvider
    extends $NotifierProvider<DistrictService, MapInfoDto?> {
  DistrictServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'districtServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$districtServiceHash();

  @$internal
  @override
  DistrictService create() => DistrictService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapInfoDto? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapInfoDto?>(value),
    );
  }
}

String _$districtServiceHash() => r'825a21b4ad2ff5f4d54c378025bff4996ed12d00';

abstract class _$DistrictService extends $Notifier<MapInfoDto?> {
  MapInfoDto? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MapInfoDto?, MapInfoDto?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MapInfoDto?, MapInfoDto?>,
              MapInfoDto?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
