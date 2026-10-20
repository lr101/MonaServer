import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  late SuppliedImageUrlRegistry registry;
  late BatchReadCoalescer batch;
  final reads = <BatchReadKind>[];
  var histories = 0;
  late PinImageSources sources;
  setUp(() {
    reads.clear();
    histories = 0;
    registry = SuppliedImageUrlRegistry();
    batch = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async {
        reads.addAll(items.map((e) => batchReadKind(batchResultKind(e.kind))));
        return [
          for (final item in items)
            BatchReadResult(
              kind: batchResultKind(item.kind),
              id: item.id,
              status: 200,
              imageUrl: 'https://storage.test/fresh/${item.kind.value}',
            ),
        ];
      },
    );
    sources = PinImageSources(
      registry: registry,
      batch: batch,
      namespace: 'session-1',
      getPhotos: (pinId) async {
        histories++;
        return [
          PinPhotoDto(
            id: 'update',
            pinId: pinId,
            contributorUsername: 'a',
            observedAt: DateTime(2026),
            image: 'https://storage.test/full',
            imageThumbnail: 'https://storage.test/thumb',
            isOriginal: false,
          ),
        ];
      },
    );
  });
  tearDown(() {
    registry.dispose();
    batch.dispose();
  });

  test(
    'uses existing thumbnail metadata without a batch or history request',
    () async {
      registry.register(
        BatchReadKind.pinImageThumbnail,
        'pin',
        'https://storage.test/thumb?signature=old',
      );
      final image = await sources.resolve((
        pinId: 'pin',
        photoId: null,
        thumbnailUrl: null,
        imageUrl: null,
        attempt: 0,
      ));
      expect(image?.url, 'https://storage.test/thumb?signature=old');
      expect(reads, isEmpty);
      expect(histories, 0);
    },
  );
  test('full fallback resolves only the full variant', () async {
    final image = await sources.resolve((
      pinId: 'pin',
      photoId: null,
      thumbnailUrl: null,
      imageUrl: null,
      attempt: 1,
    ));
    expect(image?.url, contains('/fresh/'));
    expect(reads, [BatchReadKind.pinImage]);
  });
  test(
    'expired photo URLs are renewed together once for both variants',
    () async {
      const request = (
        pinId: 'pin',
        photoId: 'update',
        thumbnailUrl: 'https://storage.test/expired',
        imageUrl: 'https://storage.test/expired-full',
        attempt: 2,
      );
      expect(
        (await sources.resolve(request))?.url,
        'https://storage.test/thumb',
      );
      expect(
        (await sources.resolve((
          pinId: 'pin',
          photoId: 'update',
          thumbnailUrl: null,
          imageUrl: null,
          attempt: 3,
        )))?.url,
        'https://storage.test/full',
      );
      expect(histories, 1);
      expect(reads, isEmpty);
    },
  );
  test(
    'signed URL renewal keeps the decoded cache key stable within a session',
    () async {
      const request = (
        pinId: 'pin',
        photoId: 'update',
        thumbnailUrl: 'https://storage.test/thumb?signature=old',
        imageUrl: null,
        attempt: 0,
      );
      final old = await sources.resolve(request);
      final renewed = await sources.resolve((
        pinId: 'pin',
        photoId: 'update',
        thumbnailUrl: 'https://storage.test/thumb?signature=new',
        imageUrl: null,
        attempt: 0,
      ));
      expect(renewed?.cacheKey, old?.cacheKey);
      expect(renewed?.url, endsWith('signature=new'));
    },
  );
  test('an absent update never resolves to the original pin photo', () async {
    final image = await sources.resolve((
      pinId: 'pin',
      photoId: 'deleted',
      thumbnailUrl: null,
      imageUrl: null,
      attempt: 2,
    ));
    expect(image, isNull);
    expect(reads, isEmpty);
  });
  test('a failed registry photo URL is bypassed during renewal', () async {
    registry.register(
      BatchReadKind.pinImageThumbnail,
      'photo:pin:update',
      'https://storage.test/expired',
    );
    final image = await sources.resolve((
      pinId: 'pin',
      photoId: 'update',
      thumbnailUrl: 'https://storage.test/expired',
      imageUrl: null,
      attempt: 2,
    ));
    expect(image?.url, 'https://storage.test/thumb');
    expect(histories, 1);
  });
  test('failed history renewal can recover on a later request', () async {
    var calls = 0;
    final recovering = PinImageSources(
      registry: registry,
      batch: batch,
      namespace: 'session',
      getPhotos: (id) async {
        if (++calls == 1) throw StateError('offline');
        return [
          PinPhotoDto(
            id: 'update',
            pinId: id,
            contributorUsername: 'a',
            observedAt: DateTime(2026),
            image: 'https://storage.test/recovered',
            isOriginal: false,
          ),
        ];
      },
    );
    const request = (
      pinId: 'pin',
      photoId: 'update',
      thumbnailUrl: null,
      imageUrl: null,
      attempt: 3,
    );
    await expectLater(recovering.resolve(request), throwsStateError);
    expect(
      (await recovering.resolve(request))?.url,
      'https://storage.test/recovered',
    );
  });
}
