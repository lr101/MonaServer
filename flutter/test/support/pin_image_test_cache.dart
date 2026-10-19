import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:transparent_image/transparent_image.dart';

/// Keep the real package download, cache and decode pipeline; replace only HTTP
/// and platform storage, which are unavailable in a VM widget test.
class PinImageTestCache extends FileService {
  final urls = <String>[];
  final Map<String, int> statuses = {};
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
    return HttpGetResponse(
      http.StreamedResponse(
        Stream.value(kTransparentImage),
        statuses[url] ?? 200,
        contentLength: kTransparentImage.length,
        headers: {'content-type': 'image/png', 'cache-control': 'max-age=3600'},
      ),
    );
  }
}
