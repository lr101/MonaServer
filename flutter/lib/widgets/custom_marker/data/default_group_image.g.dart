// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_group_image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(defaultGroupPinImage)
final defaultGroupPinImageProvider = DefaultGroupPinImageProvider._();

final class DefaultGroupPinImageProvider
    extends $FunctionalProvider<Uint8List, Uint8List, Uint8List>
    with $Provider<Uint8List> {
  DefaultGroupPinImageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultGroupPinImageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultGroupPinImageHash();

  @$internal
  @override
  $ProviderElement<Uint8List> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uint8List create(Ref ref) {
    return defaultGroupPinImage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uint8List value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uint8List>(value),
    );
  }
}

String _$defaultGroupPinImageHash() =>
    r'20d42006401a57704eb4c7d13b7e6db5f436e4cb';

@ProviderFor(defaultErrorImage)
final defaultErrorImageProvider = DefaultErrorImageProvider._();

final class DefaultErrorImageProvider
    extends $FunctionalProvider<Uint8List, Uint8List, Uint8List>
    with $Provider<Uint8List> {
  DefaultErrorImageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultErrorImageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultErrorImageHash();

  @$internal
  @override
  $ProviderElement<Uint8List> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Uint8List create(Ref ref) {
    return defaultErrorImage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Uint8List value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Uint8List>(value),
    );
  }
}

String _$defaultErrorImageHash() => r'fed1f6c9468318343ea088a6aa9ef9cb65d4b972';
