// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_item_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(feedItem)
final feedItemProvider = FeedItemProvider._();

final class FeedItemProvider
    extends $FunctionalProvider<PinEntity, PinEntity, PinEntity>
    with $Provider<PinEntity> {
  FeedItemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedItemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedItemHash();

  @$internal
  @override
  $ProviderElement<PinEntity> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinEntity create(Ref ref) {
    return feedItem(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinEntity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinEntity>(value),
    );
  }
}

String _$feedItemHash() => r'31bad5c5be6e299d2bd22303c32cf7b51c5d8ce5';
