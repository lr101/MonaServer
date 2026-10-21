import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

/// Keep the real package download, cache and decode pipeline; replace only HTTP
/// and platform storage, which are unavailable in a VM widget test.
class PinImageTestCache extends FileService {
  final urls = <String>[];
  final Map<String, int> statuses = {};
  final Map<String, Completer<void>> gates = {};
  final Map<String, Uint8List> bytes = {};
  Uint8List defaultBytes = kTransparentImage;
  late final CacheManager manager = CacheManager(
    Config(
      'pin-image-test',
      repo: NonStoringObjectProvider(),
      fileSystem: MemoryCacheSystem(),
      fileService: this,
    ),
  );

  void install() => CachedNetworkImageProvider.defaultCacheManager = manager;
  Future<void> dispose() async {
    await manager.dispose();
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    urls.add(url);
    await gates[url]?.future;
    final content = bytes[url] ?? defaultBytes;
    return HttpGetResponse(
      http.StreamedResponse(
        Stream.value(content),
        statuses[url] ?? 200,
        contentLength: content.length,
        headers: {'content-type': 'image/png', 'cache-control': 'max-age=3600'},
      ),
    );
  }
}

/// Real resolver/cache with a local transport; no application bootstrap needed.
PinImageSources createTestImageSources() {
  final registry = SuppliedImageUrlRegistry();
  final batch = BatchReadCoalescer(
    window: Duration.zero,
    read: (items) async => [
      for (final item in items)
        BatchReadResult(
          kind: batchResultKind(item.kind),
          id: item.id,
          status: 404,
        ),
    ],
  );
  addTearDown(registry.dispose);
  addTearDown(batch.dispose);
  return PinImageSources(
    registry: registry,
    batch: batch,
    namespace: 'widget-test',
    getPhotos: (_) async => [],
  );
}

Future<void> pumpImageLoads(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}
