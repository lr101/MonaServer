import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('an upload revision survives a new provider container', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);
    await first.read(imageContentRevisionsProvider.notifier).replace('user:u');
    final revision = first.read(imageContentRevisionsProvider)['user:u'];
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(imageContentRevisionsProvider)['user:u'], revision);
    expect(revision, isNotEmpty);
  });

  test(
    'avatar renewal keeps identity while content revisions replace pixels',
    () async {
      final registry = SuppliedImageUrlRegistry();
      final batch = BatchReadCoalescer(
        window: Duration.zero,
        read: (items) async => [
          for (final item in items)
            BatchReadResult(
              kind: batchResultKind(item.kind),
              id: item.id,
              status: 200,
              imageUrl: 'https://images.test/avatar?signature=new',
            ),
        ],
      );
      addTearDown(registry.dispose);
      addTearDown(batch.dispose);
      final sources = RemoteImageSources(
        pins: PinImageSources(
          registry: registry,
          batch: batch,
          getPhotos: (_) async => [],
          namespace: 'login',
        ),
        registry: registry,
        batch: batch,
      );
      const avatar = RemoteImageReference(
        kind: RemoteImageKind.user,
        id: 'u',
        thumbnailUrl: 'https://images.test/avatar?signature=old',
      );
      final before = await sources.resolve(avatar, attempt: 0);
      final renewed = await sources.resolve(avatar, attempt: 2);
      final replaced = await sources.resolve(
        avatar,
        attempt: 0,
        revision: 'uploaded',
      );
      expect(renewed?.url, endsWith('signature=new'));
      expect(renewed?.cacheKey, before?.cacheKey);
      expect(replaced?.cacheKey, isNot(before?.cacheKey));
    },
  );

  test(
    'grid and detail references share the same pin cache identity',
    () async {
      final registry = SuppliedImageUrlRegistry();
      final batch = BatchReadCoalescer(
        window: Duration.zero,
        read: (_) async => [],
      );
      addTearDown(registry.dispose);
      addTearDown(batch.dispose);
      final pins = PinImageSources(
        registry: registry,
        batch: batch,
        getPhotos: (_) async => [],
        namespace: 'login',
      );
      final sources = RemoteImageSources(
        pins: pins,
        registry: registry,
        batch: batch,
      );
      final grid = await pins.resolve((
        pinId: 'pin',
        photoId: null,
        thumbnailUrl: 'https://images.test/thumb',
        imageUrl: null,
        attempt: 0,
      ));
      final detail = await sources.resolve(
        const RemoteImageReference(
          kind: RemoteImageKind.pin,
          id: 'pin',
          thumbnailUrl: 'https://images.test/thumb',
        ),
        attempt: 0,
      );
      expect(detail?.cacheKey, grid?.cacheKey);
    },
  );
}
