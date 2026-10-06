// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_photo_history_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pinPhotoHistoryRepository)
final pinPhotoHistoryRepositoryProvider = PinPhotoHistoryRepositoryProvider._();

final class PinPhotoHistoryRepositoryProvider
    extends
        $FunctionalProvider<
          IPinPhotoHistoryRepository,
          IPinPhotoHistoryRepository,
          IPinPhotoHistoryRepository
        >
    with $Provider<IPinPhotoHistoryRepository> {
  PinPhotoHistoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinPhotoHistoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinPhotoHistoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<IPinPhotoHistoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IPinPhotoHistoryRepository create(Ref ref) {
    return pinPhotoHistoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IPinPhotoHistoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IPinPhotoHistoryRepository>(value),
    );
  }
}

String _$pinPhotoHistoryRepositoryHash() =>
    r'09bf6e239e35e2e0351c54da87c0dc068f9d9d9c';
