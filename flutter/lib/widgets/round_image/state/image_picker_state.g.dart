// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_picker_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImagePickerState)
final imagePickerStateProvider = ImagePickerStateProvider._();

final class ImagePickerStateProvider
    extends $AsyncNotifierProvider<ImagePickerState, Uint8List?> {
  ImagePickerStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imagePickerStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imagePickerStateHash();

  @$internal
  @override
  ImagePickerState create() => ImagePickerState();
}

String _$imagePickerStateHash() => r'c8feebfd2990e0c049a75cae74a4a0eb2be91ab5';

abstract class _$ImagePickerState extends $AsyncNotifier<Uint8List?> {
  FutureOr<Uint8List?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Uint8List?>, Uint8List?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Uint8List?>, Uint8List?>,
              AsyncValue<Uint8List?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
