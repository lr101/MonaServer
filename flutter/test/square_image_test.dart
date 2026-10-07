import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('decodes grid images at their physical display width', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(kTransparentImage);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinThumbnailRepositoryProvider.overrideWithValue(
            _ImageRepository(bytes, ImageType.pinThumbnail),
          ),
          pinImageRepositoryProvider.overrideWithValue(
            _ImageRepository(null, ImageType.pin),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(devicePixelRatio: 3),
            child: Center(
              child: SizedBox.square(
                dimension: 100,
                child: SquareImage(
                  pinId: 'pin-1',
                  groupId: 'group-1',
                  index: 0,
                  onTap: _ignoreTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;

    expect(provider.width, 300);
    expect((provider.imageProvider as MemoryImage).bytes, same(bytes));
  });

  testWidgets('shows a placeholder when a pin image is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinThumbnailRepositoryProvider.overrideWithValue(
            _ImageRepository(null, ImageType.pinThumbnail),
          ),
          pinImageRepositoryProvider.overrideWithValue(
            _ImageRepository(null, ImageType.pin),
          ),
        ],
        child: const MaterialApp(
          home: SquareImage(
            pinId: 'pin-1',
            groupId: 'group-1',
            index: 0,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('uses the photo thumbnail without fetching its full image', (
    tester,
  ) async {
    final thumbnailBytes = Uint8List.fromList(kTransparentImage);
    final fullImageBytes = Uint8List.fromList(kTransparentImage);
    final thumbnailRepository = _ImageRepository(
      null,
      ImageType.pinThumbnail,
      updateImage: thumbnailBytes,
    );
    final fullImageRepository = _ImageRepository(
      null,
      ImageType.pin,
      updateImage: fullImageBytes,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinThumbnailRepositoryProvider.overrideWithValue(thumbnailRepository),
          pinImageRepositoryProvider.overrideWithValue(fullImageRepository),
        ],
        child: const MaterialApp(
          home: SizedBox.square(
            dimension: 100,
            child: SquareImage(
              pinId: 'place',
              photoId: 'update-photo',
              photoUrl: 'https://example.test/update.png',
              photoThumbnailUrl: 'https://example.test/update-small.png',
              groupId: 'group',
              index: 0,
              onTap: _ignoreTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(thumbnailRepository.requestedPhotoId, 'photo:update-photo');
    expect(
      thumbnailRepository.requestedPhotoUrl,
      'https://example.test/update-small.png',
    );
    expect(fullImageRepository.requestedPhotoUrl, isNull);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      ((image.image as ResizeImage).imageProvider as MemoryImage).bytes,
      same(thumbnailBytes),
    );
  });

  testWidgets('shows thumbnail bytes as soon as the shared cache updates', (
    tester,
  ) async {
    final thumbnailBytes = Uint8List.fromList(kTransparentImage);
    final thumbnailUpdates = StreamController<Uint8List?>.broadcast();
    addTearDown(thumbnailUpdates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinThumbnailRepositoryProvider.overrideWithValue(
            _ImageRepository(
              null,
              ImageType.pinThumbnail,
              imageUpdates: thumbnailUpdates.stream,
            ),
          ),
          pinImageRepositoryProvider.overrideWithValue(
            _ImageRepository(null, ImageType.pin),
          ),
        ],
        child: const MaterialApp(
          home: SquareImage(
            pinId: 'pin-1',
            groupId: 'group-1',
            index: 0,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

    thumbnailUpdates.add(thumbnailBytes);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect((provider.imageProvider as MemoryImage).bytes, same(thumbnailBytes));
  });

  testWidgets(
    'falls back to the full image when the thumbnail is unavailable',
    (tester) async {
      final bytes = Uint8List.fromList(kTransparentImage);
      int? tappedIndex;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinThumbnailRepositoryProvider.overrideWithValue(
              _ImageRepository(null, ImageType.pinThumbnail),
            ),
            pinImageRepositoryProvider.overrideWithValue(
              _ImageRepository(bytes, ImageType.pin),
            ),
          ],
          child: MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 100,
                child: SquareImage(
                  pinId: 'pin-1',
                  groupId: 'group-1',
                  index: 7,
                  onTap: (index) => tappedIndex = index,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as ResizeImage;
      expect((provider.imageProvider as MemoryImage).bytes, same(bytes));

      await tester.tap(find.byType(SquareImage));
      expect(tappedIndex, 7);
    },
  );
}

void _ignoreTap(int index) {}

class _ImageRepository implements IImageRepository {
  _ImageRepository(
    this.image,
    this.type, {
    this.updateImage,
    this.imageUpdates,
  });

  final Uint8List? image;
  final Uint8List? updateImage;
  final Stream<Uint8List?>? imageUpdates;
  String? requestedPhotoId;
  String? requestedPhotoUrl;

  @override
  final ImageType type;

  @override
  Future<Uint8List?> fetchImage(
    String id,
    bool keepAlive, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async => image;

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive, {
    bool fallbackToEndpoint = true,
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async {
    requestedPhotoId = id;
    requestedPhotoUrl = url;
    return updateImage;
  }

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<ImageEntity?> get(String id) async => null;

  @override
  Future<List<ImageEntity>> getAll() async => [];

  @override
  Future<List<ImageEntity?>> getList(List<String> ids) async => [];

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async =>
      Uint8List(0);

  @override
  Future<void> put(ImageEntity item) async {}

  @override
  Future<void> putMultiple(List<ImageEntity> items) async {}

  @override
  Stream<ImageEntity?> watchById(String id) => Stream.value(null);

  @override
  Stream<Uint8List?> watchImageBytes(String id) =>
      imageUpdates ?? Stream.value(null);
}
