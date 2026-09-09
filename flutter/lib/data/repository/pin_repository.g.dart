// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pinRepository)
final pinRepositoryProvider = PinRepositoryProvider._();

final class PinRepositoryProvider
    extends $FunctionalProvider<IPinRepository, IPinRepository, IPinRepository>
    with $Provider<IPinRepository> {
  PinRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinRepositoryHash();

  @$internal
  @override
  $ProviderElement<IPinRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IPinRepository create(Ref ref) {
    return pinRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IPinRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IPinRepository>(value),
    );
  }
}

String _$pinRepositoryHash() => r'7d7a40bc202202b461df44f9d72a024f00ae6545';

@ProviderFor(pinLikeRepository)
final pinLikeRepositoryProvider = PinLikeRepositoryProvider._();

final class PinLikeRepositoryProvider
    extends
        $FunctionalProvider<
          IPinLikeRepository,
          IPinLikeRepository,
          IPinLikeRepository
        >
    with $Provider<IPinLikeRepository> {
  PinLikeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinLikeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinLikeRepositoryHash();

  @$internal
  @override
  $ProviderElement<IPinLikeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IPinLikeRepository create(Ref ref) {
    return pinLikeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IPinLikeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IPinLikeRepository>(value),
    );
  }
}

String _$pinLikeRepositoryHash() => r'9426e294ae110577b5b4ed2655f09071680e98d1';
