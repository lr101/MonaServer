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
          pinImageRepositoryProvider.overrideWithValue(_ImageRepository(bytes)),
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
    await tester.pump();

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
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
          pinImageRepositoryProvider.overrideWithValue(_ImageRepository(null)),
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
    await tester.pump();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}

void _ignoreTap(int index) {}

class _ImageRepository implements IImageRepository {
  _ImageRepository(this.image);

  final Uint8List? image;

  @override
  ImageType get type => ImageType.pin;

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async => image;

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive,
  ) async => null;

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
  Stream<Uint8List?> watchImageBytes(String id) => Stream.value(null);
}
