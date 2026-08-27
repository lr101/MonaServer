// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CameraIndex)
final cameraIndexProvider = CameraIndexProvider._();

final class CameraIndexProvider extends $NotifierProvider<CameraIndex, int> {
  CameraIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraIndexHash();

  @$internal
  @override
  CameraIndex create() => CameraIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$cameraIndexHash() => r'1586261879e9dbbace237e964af490a507397937';

abstract class _$CameraIndex extends $Notifier<int> {
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

@ProviderFor(CameraValues)
final cameraValuesProvider = CameraValuesProvider._();

final class CameraValuesProvider
    extends $AsyncNotifierProvider<CameraValues, CameraState> {
  CameraValuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraValuesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraValuesHash();

  @$internal
  @override
  CameraValues create() => CameraValues();
}

String _$cameraValuesHash() => r'52a21170a1267379621b67872fc9ff5d1b615790';

abstract class _$CameraValues extends $AsyncNotifier<CameraState> {
  FutureOr<CameraState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CameraState>, CameraState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CameraState>, CameraState>,
              AsyncValue<CameraState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(cameraController)
final cameraControllerProvider = CameraControllerProvider._();

final class CameraControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<CameraController>,
          CameraController,
          FutureOr<CameraController>
        >
    with $FutureModifier<CameraController>, $FutureProvider<CameraController> {
  CameraControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraControllerHash();

  @$internal
  @override
  $FutureProviderElement<CameraController> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CameraController> create(Ref ref) {
    return cameraController(ref);
  }
}

String _$cameraControllerHash() => r'babeccea41cd9c8976ba0f674841adbd0548ab87';

@ProviderFor(CameraGroupIndex)
final cameraGroupIndexProvider = CameraGroupIndexProvider._();

final class CameraGroupIndexProvider
    extends $NotifierProvider<CameraGroupIndex, int> {
  CameraGroupIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraGroupIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraGroupIndexHash();

  @$internal
  @override
  CameraGroupIndex create() => CameraGroupIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$cameraGroupIndexHash() => r'c4af013786fcd5c4ccd6b06e8abc6500005a9107';

abstract class _$CameraGroupIndex extends $Notifier<int> {
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

@ProviderFor(cameraSelectedGroup)
final cameraSelectedGroupProvider = CameraSelectedGroupProvider._();

final class CameraSelectedGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupEntity?>,
          GroupEntity?,
          FutureOr<GroupEntity?>
        >
    with $FutureModifier<GroupEntity?>, $FutureProvider<GroupEntity?> {
  CameraSelectedGroupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraSelectedGroupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraSelectedGroupHash();

  @$internal
  @override
  $FutureProviderElement<GroupEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GroupEntity?> create(Ref ref) {
    return cameraSelectedGroup(ref);
  }
}

String _$cameraSelectedGroupHash() =>
    r'25fe15f4c2b72eebd84a4523a311324e0d5cae5f';

@ProviderFor(CameraCapturing)
final cameraCapturingProvider = CameraCapturingProvider._();

final class CameraCapturingProvider
    extends $NotifierProvider<CameraCapturing, bool> {
  CameraCapturingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraCapturingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraCapturingHash();

  @$internal
  @override
  CameraCapturing create() => CameraCapturing();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cameraCapturingHash() => r'085c4bc10e7ad57d76a4866256c2ffdd6d795047';

abstract class _$CameraCapturing extends $Notifier<bool> {
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
