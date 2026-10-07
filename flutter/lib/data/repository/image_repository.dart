import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_repository.g.dart';

Future<http.Response> _defaultImageHttpGet(
  Uri uri,
  ImageRequestCancellation? cancellation,
) async {
  final client = http.Client();
  try {
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: cancellation?.whenCancelled,
    );
    return await http.Response.fromStream(await client.send(request));
  } finally {
    client.close();
  }
}

/// A visible or look-ahead owner cancels this when its image is no longer needed.
class ImageRequestCancellation {
  final Completer<void> _completion = Completer<void>();
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;

  void addListener(void Function() listener) {
    if (isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void cancel() {
    if (isCancelled) return;
    _completion.complete();
    for (final listener in _listeners.toList(growable: false)) {
      listener();
    }
    _listeners.clear();
  }
}

class _ImageRequestCancelled implements Exception {
  const _ImageRequestCancelled();
}

class _ImageWriteQueue {
  Future<void> tail = Future<void>.value();
  int pending = 0;
}

enum ImageRequestPriority { foreground, background }

/// Bounds object downloads shared by every image repository in one session.
/// Visible requests take the next free permit before look-ahead work.
class ImageDownloadScheduler {
  ImageDownloadScheduler({int maxConcurrent = 6})
    : _maxConcurrent = maxConcurrent < 1 ? 1 : maxConcurrent;

  final int _maxConcurrent;
  final Queue<_ImageDownloadWaiter> _foreground = Queue();
  final Queue<_ImageDownloadWaiter> _background = Queue();
  final Map<Object, _ImageDownloadWaiter> _queuedByRequest = {};
  int _active = 0;

  Future<T> run<T>(
    Future<T> Function() operation, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    Object? request,
    ImageRequestCancellation? cancellation,
  }) async {
    await _acquire(priority, request, cancellation);
    try {
      if (cancellation?.isCancelled == true) {
        throw const _ImageRequestCancelled();
      }
      return await operation();
    } finally {
      _release();
    }
  }

  void reprioritize(Object request, ImageRequestPriority priority) {
    final waiter = _queuedByRequest[request];
    if (waiter == null ||
        waiter.ready.isCompleted ||
        waiter.priority == priority) {
      return;
    }
    final previousQueue = waiter.priority == ImageRequestPriority.foreground
        ? _foreground
        : _background;
    if (!previousQueue.remove(waiter)) return;
    waiter.priority = priority;
    (priority == ImageRequestPriority.foreground ? _foreground : _background)
        .addLast(waiter);
  }

  Future<void> _acquire(
    ImageRequestPriority priority,
    Object? request,
    ImageRequestCancellation? cancellation,
  ) {
    if (cancellation?.isCancelled == true) {
      return Future<void>.error(const _ImageRequestCancelled());
    }
    if (_active < _maxConcurrent &&
        _foreground.isEmpty &&
        _background.isEmpty) {
      _active++;
      return Future<void>.value();
    }
    final waiter = _ImageDownloadWaiter(priority);
    if (request != null) _queuedByRequest[request] = waiter;
    (priority == ImageRequestPriority.foreground ? _foreground : _background)
        .addLast(waiter);
    void cancelWaiter() {
      if (waiter.ready.isCompleted) return;
      if (_foreground.remove(waiter) || _background.remove(waiter)) {
        waiter.ready.completeError(const _ImageRequestCancelled());
      }
    }

    cancellation?.addListener(cancelWaiter);
    return waiter.ready.future.whenComplete(() {
      cancellation?.removeListener(cancelWaiter);
      if (request != null && identical(_queuedByRequest[request], waiter)) {
        _queuedByRequest.remove(request);
      }
    });
  }

  void _release() {
    final waiter = _foreground.isNotEmpty
        ? _foreground.removeFirst()
        : _background.isNotEmpty
        ? _background.removeFirst()
        : null;
    if (waiter == null) {
      _active--;
      return;
    }
    waiter.ready.complete();
  }
}

class _ImageDownloadWaiter {
  _ImageDownloadWaiter(this.priority);

  ImageRequestPriority priority;
  final Completer<void> ready = Completer<void>();
}

class _ImageRequestConsumer {
  _ImageRequestConsumer(this.priority, this.detach);

  ImageRequestPriority priority;
  final void Function() detach;
}

class _ActiveImageRequest {
  _ActiveImageRequest(
    this.initialKeepAlive, {
    required this.contentVersion,
    this.retainedImage,
    required this.priority,
  }) : keepAlive = initialKeepAlive;

  final bool initialKeepAlive;
  final int contentVersion;
  final ImageEntity? retainedImage;
  bool keepAlive;
  ImageRequestPriority priority;
  final ImageRequestCancellation abort = ImageRequestCancellation();
  final Map<ImageRequestCancellation, _ImageRequestConsumer> _consumers = {};
  bool _hasUncancelledConsumer = false;
  bool _hasUncancelledForegroundConsumer = false;
  late final Future<Uint8List?> future;

  bool get isCancelled => abort.isCancelled;

  void addConsumer(
    ImageRequestCancellation? cancellation,
    ImageRequestPriority consumerPriority,
    void Function() onUnobserved,
    void Function(ImageRequestPriority) onPriorityChanged,
  ) {
    if (cancellation == null) {
      _hasUncancelledConsumer = true;
      if (consumerPriority == ImageRequestPriority.foreground) {
        _hasUncancelledForegroundConsumer = true;
      }
      _recomputePriority(onPriorityChanged);
      return;
    }
    final existing = _consumers[cancellation];
    if (existing != null) {
      if (consumerPriority == ImageRequestPriority.foreground) {
        existing.priority = consumerPriority;
        _recomputePriority(onPriorityChanged);
      }
      return;
    }
    void detach() {
      final consumer = _consumers.remove(cancellation);
      if (consumer != null) cancellation.removeListener(consumer.detach);
      if (!_hasUncancelledConsumer && _consumers.isEmpty) {
        abort.cancel();
        onUnobserved();
      } else {
        _recomputePriority(onPriorityChanged);
      }
    }

    _consumers[cancellation] = _ImageRequestConsumer(consumerPriority, detach);
    cancellation.addListener(detach);
    _recomputePriority(onPriorityChanged);
  }

  void _recomputePriority(
    void Function(ImageRequestPriority) onPriorityChanged,
  ) {
    final next =
        _hasUncancelledForegroundConsumer ||
            _consumers.values.any(
              (consumer) =>
                  consumer.priority == ImageRequestPriority.foreground,
            )
        ? ImageRequestPriority.foreground
        : ImageRequestPriority.background;
    if (priority == next) return;
    priority = next;
    onPriorityChanged(next);
  }

  void clearConsumers() {
    for (final entry in _consumers.entries) {
      entry.key.removeListener(entry.value.detach);
    }
    _consumers.clear();
  }
}

abstract class IImageRepository implements CacheApi<ImageEntity> {
  ImageType get type;
  Future<Uint8List?> fetchImage(
    String id,
    bool keepAlive, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  });
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive, {
    bool fallbackToEndpoint = true,
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  });
  Stream<Uint8List?> watchImageBytes(String id);
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive);
  Future<void> addImage(String id, Uint8List image, bool keepAlive);
}

class ImageRepository extends CacheImpl<ImageEntity>
    implements IImageRepository {
  /// A bounded stale-while-revalidate cache for remote image bytes.
  ///
  /// Missing images are represented by a TTL-bound empty row, transient
  /// failures keep serving stale bytes, and only non-keep-alive rows count
  /// toward the bounded eviction set. The database row is the source of
  /// truth; Flutter's image cache is populated by the presentation layer.
  final AppDatabase db;
  final Future<String?> Function(String) getImageUrl;
  final String? Function(String)? getSuppliedImageUrl;
  final void Function(String, String)? invalidateSuppliedImageUrl;
  final bool Function()? isSessionCurrent;
  final Future<http.Response> Function(Uri, ImageRequestCancellation?) _httpGet;
  final Duration httpTimeout;
  final Duration negativeTtlDuration;
  final int _maxMemoryCacheItems;
  final ImageDownloadScheduler _downloadScheduler;
  @override
  final ImageType type;

  bool _disposed = false;

  bool get _canFetchRemote =>
      !_disposed && (isSessionCurrent == null || isSessionCurrent!());

  bool _canContinue(_ActiveImageRequest request) =>
      _canFetchRemote && !request.isCancelled;

  void dispose() {
    _disposed = true;
    db.session?.removeListener(dispose);
    for (final request in _activeRequests.values) {
      request.abort.cancel();
      request.clearConsumers();
    }
    _bytesCache.clear();
    _activeRequests.clear();
    _imageContentVersions.clear();
    _nextReplacementVersions.clear();
    _committedReplacementVersions.clear();
    _pendingImageRequests.clear();
    _pendingReplacementOperations.clear();
  }

  final Map<String, _ActiveImageRequest> _activeRequests = {};
  final Map<String, _ImageWriteQueue> _writeQueues = {};
  final Map<String, int> _imageContentVersions = {};
  final Map<String, int> _nextReplacementVersions = {};
  final Map<String, int> _committedReplacementVersions = {};
  final Map<String, int> _pendingImageRequests = {};
  final Map<String, int> _pendingReplacementOperations = {};
  final Map<String, int> _activeWatchers = {};
  final LinkedHashMap<String, Uint8List> _bytesCache =
      LinkedHashMap<String, Uint8List>();
  Future<void> _pruneQueue = Future<void>.value();

  ImageRepository({
    required this.db,
    required this.getImageUrl,
    this.getSuppliedImageUrl,
    this.invalidateSuppliedImageUrl,
    this.isSessionCurrent,
    required this.type,
    Future<http.Response> Function(Uri)? httpGet,
    this.httpTimeout = const Duration(seconds: 15),
    this.negativeTtlDuration = const Duration(minutes: 2),
    int maxMemoryCacheItems = 50,
    int maxConcurrentDownloads = 6,
    ImageDownloadScheduler? downloadScheduler,
    super.maxItems,
    super.ttlDuration,
  }) : _httpGet = httpGet == null
           ? _defaultImageHttpGet
           : ((uri, _) => httpGet(uri)),
       _maxMemoryCacheItems = maxMemoryCacheItems < 1 ? 1 : maxMemoryCacheItems,
       _downloadScheduler =
           downloadScheduler ??
           ImageDownloadScheduler(maxConcurrent: maxConcurrentDownloads) {
    db.session?.onRevoke(dispose);
  }

  Future<http.Response> _getHttpResponse(
    Uri uri,
    ImageRequestCancellation? cancellation,
  ) async {
    // Abort the transport on either owner cancellation or timeout. Awaiting
    // transport completion keeps the scheduler permit occupied until it stops.
    final attempt = ImageRequestCancellation();
    void cancelAttempt() => attempt.cancel();
    cancellation?.addListener(cancelAttempt);
    var timedOut = false;
    final timer = Timer(httpTimeout, () {
      timedOut = true;
      attempt.cancel();
    });
    try {
      if (attempt.isCancelled) throw const _ImageRequestCancelled();
      final response = await _httpGet(uri, attempt);
      if (timedOut) throw TimeoutException('Image download timed out.');
      if (attempt.isCancelled) throw const _ImageRequestCancelled();
      return response;
    } finally {
      timer.cancel();
      cancellation?.removeListener(cancelAttempt);
    }
  }

  String _cacheKey(String id) => '${type.name}:$id';

  int _contentVersion(String cacheKey) => _imageContentVersions[cacheKey] ?? 0;

  int _issueReplacementVersion(String cacheKey) {
    _pendingReplacementOperations.update(
      cacheKey,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return _nextReplacementVersions.update(
      cacheKey,
      (version) => version + 1,
      ifAbsent: () => 1,
    );
  }

  void _finishReplacementOperation(String cacheKey) {
    final pending = _pendingReplacementOperations[cacheKey];
    if (pending == null || pending <= 1) {
      _pendingReplacementOperations.remove(cacheKey);
    } else {
      _pendingReplacementOperations[cacheKey] = pending - 1;
    }
    _cleanupGenerationState(cacheKey);
  }

  void _finishImageRequest(String cacheKey) {
    final pending = _pendingImageRequests[cacheKey];
    if (pending == null || pending <= 1) {
      _pendingImageRequests.remove(cacheKey);
    } else {
      _pendingImageRequests[cacheKey] = pending - 1;
    }
    _cleanupGenerationState(cacheKey);
  }

  void _cleanupGenerationState(String cacheKey) {
    if (_pendingImageRequests.containsKey(cacheKey) ||
        _pendingReplacementOperations.containsKey(cacheKey) ||
        _writeQueues.containsKey(cacheKey)) {
      return;
    }
    _imageContentVersions.remove(cacheKey);
    _nextReplacementVersions.remove(cacheKey);
    _committedReplacementVersions.remove(cacheKey);
  }

  @override
  int cacheIdFor(String id) => fastHash(_cacheKey(id));

  void _rememberBytes(String id, Uint8List bytes) {
    if (_disposed || bytes.isEmpty) return;

    final cachedBytes = _bytesCache[id];
    if (cachedBytes != null && listEquals(cachedBytes, bytes)) {
      _bytesCache.remove(id);
      _bytesCache[id] = cachedBytes;
      return;
    }

    if (_bytesCache.length >= _maxMemoryCacheItems &&
        !_bytesCache.containsKey(id)) {
      final oldestUnprotected = _bytesCache.keys.firstWhere(
        (key) => !_isProtected(_cacheKey(key)),
        orElse: () => _bytesCache.keys.first,
      );
      _bytesCache.remove(oldestUnprotected);
    }

    _bytesCache.remove(id);
    _bytesCache[id] = bytes;
  }

  Uint8List? _readMemoryBytes(String id) {
    final bytes = _bytesCache.remove(id);
    if (bytes == null) return null;
    _bytesCache[id] = bytes;
    return bytes;
  }

  void _removeMemoryBytes(String id) {
    _bytesCache.remove(id);
  }

  bool _isProtected(String cacheKey) {
    return _activeWatchers.containsKey(cacheKey) ||
        _activeRequests.containsKey(cacheKey);
  }

  Future<Uint8List?> _joinActiveRequest(
    String id,
    String cacheKey,
    _ActiveImageRequest request,
    bool keepAlive,
    ImageRequestPriority priority,
    ImageRequestCancellation? cancellation,
  ) async {
    if (cancellation?.isCancelled == true) return null;
    request.addConsumer(cancellation, priority, () {
      if (identical(_activeRequests[cacheKey], request)) {
        _activeRequests.remove(cacheKey);
      }
    }, (priority) => _downloadScheduler.reprioritize(request, priority));
    request.keepAlive = request.keepAlive || keepAlive;
    final image = await request.future;
    if (cancellation?.isCancelled == true || _disposed) return null;
    if (request.keepAlive) await _promoteKeepAlive(id);
    return image;
  }

  Future<T> _enqueueWrite<T>(String cacheKey, Future<T> Function() write) {
    final queue = _writeQueues.putIfAbsent(cacheKey, _ImageWriteQueue.new);
    queue.pending++;
    final operation = queue.tail.then<T>((_) => write());
    queue.tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation.whenComplete(() {
      queue.pending--;
      if (queue.pending == 0 && identical(_writeQueues[cacheKey], queue)) {
        _writeQueues.remove(cacheKey);
      }
    });
  }

  // --- DRIFT DB MAPPERS ---

  ImageEntitiesCompanion _toCompanion(ImageEntity entity) {
    return ImageEntitiesCompanion(
      cacheKey: Value(entity.cacheKey),
      id: Value(entity.id),
      type: Value(entity.type),
      image: Value(entity.image),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
      lastAccessedAt: Value(entity.lastAccessedAt),
    );
  }

  ImageEntity _fromDb(ImageDb data) {
    return ImageEntity(
      id: data.id,
      type: data.type,
      image: data.image,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
      lastAccessedAt: data.lastAccessedAt,
    );
  }

  // --- CACHE API ---

  @override
  Future<void> put(ImageEntity item) async {
    await ready;
    await doPut(item);
    if (item.image case final image? when image.isNotEmpty) {
      _rememberBytes(item.id, image);
    }
    await _enqueuePrune();
  }

  @override
  Future<void> putMultiple(Iterable<ImageEntity> items) async {
    await ready;
    final values = items.toList();
    await doPutMultiple(values);
    for (final item in values) {
      if (item.image case final image? when image.isNotEmpty) {
        _rememberBytes(item.id, image);
      }
    }
    await _enqueuePrune();
  }

  @override
  Stream<ImageEntity?> watchById(String id) {
    return Stream.fromFuture(ready)
        .asyncExpand((_) => _watchByCacheKey(_cacheKey(id)));
  }

  @override
  Future<ImageEntity?> get(String id) async {
    await ready;
    final entity = await _getByCacheKey(_cacheKey(id));
    if (entity != null) await _touch(entity);
    return entity;
  }

  @override
  Future<void> delete(String id) async {
    await ready;
    await _deleteByCacheKey(_cacheKey(id));
    _removeMemoryBytes(id);
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    await ready;
    final keys = ids.map(_cacheKey).toList();
    if (keys.isEmpty) return;
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keys))).go();
    for (final id in ids) {
      _removeMemoryBytes(id);
    }
  }

  @override
  Future<void> deleteAll() async {
    await ready;
    await doDeleteAll();
    _bytesCache.clear();
  }

  @override
  Future<List<ImageEntity?>> getList(List<String> ids) async {
    await ready;
    if (ids.isEmpty) return [];

    final keys = ids.map(_cacheKey).toList();
    final rows = await (db.select(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keys))).get();
    final entities = {for (final row in rows) row.cacheKey: _fromDb(row)};
    return ids.map((id) => entities[_cacheKey(id)]).toList();
  }

  @override
  Future<void> deleteOldestItems() async {
    await ready;
    await _enqueuePrune();
  }

  // --- DRIFT CACHE OPERATIONS ---

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.equals(isarId),
        ))
        .go();
  }

  @override
  Future<void> doDeleteAll() async {
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    if (isarIds.isEmpty) return;
    await (db.delete(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.isIn(isarIds),
        ))
        .go();
  }

  @override
  Future<ImageEntity?> doGet(int isarId) async {
    final result =
        await (db.select(db.imageEntities)..where(
              (table) =>
                  table.type.equalsValue(type) & table.isarId.equals(isarId),
            ))
            .getSingleOrNull();
    return result == null ? null : _fromDb(result);
  }

  @override
  Future<List<ImageEntity>> doGetAll() async {
    final result = await (db.select(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<List<ImageEntity>> doGetList(List<int> isarIds) async {
    if (isarIds.isEmpty) return [];
    final result =
        await (db.select(db.imageEntities)..where(
              (table) =>
                  table.type.equalsValue(type) & table.isarId.isIn(isarIds),
            ))
            .get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final count = db.imageEntities.cacheKey.count();
    final query = db.selectOnly(db.imageEntities)
      ..where(db.imageEntities.type.equalsValue(type))
      ..addColumns([count]);
    final result = await query.getSingleOrNull();
    return result?.read(count) ?? 0;
  }

  @override
  Future<List<ImageEntity>> doGetSortedByHits() async {
    final result =
        await (db.select(db.imageEntities)
              ..where((table) => table.type.equalsValue(type))
              ..orderBy([
                (table) => OrderingTerm(expression: table.hits),
                (table) => OrderingTerm(expression: table.cacheKey),
              ]))
            .get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(ImageEntity item) async {
    await db.into(db.imageEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<ImageEntity> items) async {
    if (items.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.imageEntities,
        items.map(_toCompanion).toList(),
      );
    });
  }

  @override
  Future<void> startup() async {
    final now = DateTime.now();
    final all = await doGetAll();
    final expired = all.where(
      (entry) =>
          (entry.onlySession && !entry.keepAlive) ||
          (!entry.keepAlive && entry.ttl.isBefore(now)),
    );
    await doDeleteMultiple(expired.map((entry) => entry.isarId).toList());
  }

  @override
  Stream<ImageEntity?> doWatchById(int isarId) {
    return (db.select(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.equals(isarId),
        ))
        .watchSingleOrNull()
        .map((result) => result == null ? null : _fromDb(result));
  }

  Future<ImageEntity?> _getByCacheKey(String cacheKey) async {
    final result = await (db.select(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(cacheKey))).getSingleOrNull();
    return result == null ? null : _fromDb(result);
  }

  Future<void> _deleteByCacheKey(String cacheKey) async {
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(cacheKey))).go();
  }

  Stream<ImageEntity?> _watchByCacheKey(String cacheKey) {
    final controller = StreamController<ImageEntity?>.broadcast();
    StreamSubscription<ImageDb?>? sourceSubscription;

    controller.onListen = () {
      _activeWatchers.update(cacheKey, (count) => count + 1, ifAbsent: () => 1);
      sourceSubscription =
          (db.select(db.imageEntities)
                ..where((table) => table.cacheKey.equals(cacheKey)))
              .watchSingleOrNull()
              .listen(
                (row) => controller.add(row == null ? null : _fromDb(row)),
                onError: controller.addError,
                onDone: controller.close,
              );
    };

    controller.onCancel = () async {
      final count = _activeWatchers[cacheKey];
      if (count == null || count <= 1) {
        _activeWatchers.remove(cacheKey);
      } else {
        _activeWatchers[cacheKey] = count - 1;
      }
      await sourceSubscription?.cancel();
      sourceSubscription = null;
      await _enqueuePrune();
    };

    return controller.stream;
  }

  Stream<Uint8List?> _watchBytesByCacheKey(String cacheKey) {
    return _watchByCacheKey(cacheKey).map((entity) {
      final image = entity?.image;
      if (image == null || image.isEmpty) return null;
      _rememberBytes(entity!.id, image);
      return _readMemoryBytes(entity.id);
    });
  }

  @override
  Stream<Uint8List?> watchImageBytes(String id) {
    return Stream.fromFuture(ready)
        .asyncExpand((_) => _watchBytesByCacheKey(_cacheKey(id)))
        .distinct();
  }

  // --- NETWORK AND DB CACHE OPERATIONS ---

  @override
  Future<Uint8List?> fetchImage(
    String id,
    bool keepAlive, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async {
    await ready;
    if (_disposed || cancellation?.isCancelled == true) return null;
    final cacheKey = _cacheKey(id);
    final contentVersion = _contentVersion(cacheKey);
    final activeRequest = _activeRequests[cacheKey];
    if (activeRequest != null &&
        !activeRequest.isCancelled &&
        activeRequest.contentVersion == contentVersion) {
      return _joinActiveRequest(
        id,
        cacheKey,
        activeRequest,
        keepAlive,
        priority,
        cancellation,
      );
    }

    final now = DateTime.now();
    final cachedImage = await _getByCacheKey(cacheKey);
    final retainedImage = cachedImage?.keepAlive == true ? cachedImage : null;
    if (cachedImage != null) {
      final image = cachedImage.image;
      if (image != null && image.isNotEmpty) {
        _rememberBytes(id, image);
        await _touch(cachedImage, keepAlive: keepAlive);
        if (_disposed) return null;
        final bytes = _readMemoryBytes(id)!;
        if (cachedImage.ttl.isAfter(now)) return bytes;
        return _fetchWithDedup(
          id,
          keepAlive,
          fallback: bytes,
          imageUrl: getSuppliedImageUrl?.call(id),
          retainedImage: retainedImage,
          contentVersion: contentVersion,
          priority: priority,
          cancellation: cancellation,
        );
      }

      if (image != null && image.isEmpty && cachedImage.ttl.isAfter(now)) {
        await _touch(cachedImage, keepAlive: keepAlive);
        final suppliedUrl = getSuppliedImageUrl?.call(id);
        if (suppliedUrl == null || suppliedUrl.isEmpty) return null;
        return _fetchWithDedup(
          id,
          keepAlive,
          imageUrl: suppliedUrl,
          retainedImage: retainedImage,
          contentVersion: contentVersion,
          priority: priority,
          cancellation: cancellation,
        );
      }
    }

    return _fetchWithDedup(
      id,
      keepAlive,
      imageUrl: getSuppliedImageUrl?.call(id),
      retainedImage: retainedImage,
      contentVersion: contentVersion,
      priority: priority,
      cancellation: cancellation,
    );
  }

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive, {
    bool fallbackToEndpoint = true,
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async {
    await ready;
    if (_disposed || cancellation?.isCancelled == true) return null;
    final cacheKey = _cacheKey(id);
    final contentVersion = _contentVersion(cacheKey);
    final activeRequest = _activeRequests[cacheKey];
    if (activeRequest != null &&
        !activeRequest.isCancelled &&
        activeRequest.contentVersion == contentVersion) {
      return _joinActiveRequest(
        id,
        cacheKey,
        activeRequest,
        keepAlive,
        priority,
        cancellation,
      );
    }

    final now = DateTime.now();
    final cachedImage = await _getByCacheKey(cacheKey);
    Uint8List? fallback;
    var effectiveKeepAlive = keepAlive;
    if (cachedImage != null) {
      effectiveKeepAlive = keepAlive || cachedImage.keepAlive;
      final image = cachedImage.image;
      if (image != null && image.isNotEmpty) {
        _rememberBytes(id, image);
        await _touch(cachedImage, keepAlive: keepAlive);
        if (_disposed) return null;
        fallback = _readMemoryBytes(id)!;
        if (cachedImage.ttl.isAfter(now)) return fallback;
      } else if (image != null && image.isEmpty) {
        // A search response can provide a newly valid URL after a previous
        // request cached a temporary missing-image result.
        await _touch(cachedImage, keepAlive: keepAlive);
      }
    }

    return _fetchWithDedup(
      id,
      effectiveKeepAlive,
      fallback: fallback,
      imageUrl: url,
      contentVersion: contentVersion,
      fallbackToEndpoint: fallbackToEndpoint,
      priority: priority,
      cancellation: cancellation,
    );
  }

  Future<Uint8List?> _fetchWithDedup(
    String id,
    bool keepAlive, {
    Uint8List? fallback,
    String? imageUrl,
    ImageEntity? retainedImage,
    required int contentVersion,
    bool fallbackToEndpoint = true,
    required ImageRequestPriority priority,
    ImageRequestCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled == true) return null;
    final cacheKey = _cacheKey(id);
    final activeRequest = _activeRequests[cacheKey];
    if (activeRequest != null &&
        !activeRequest.isCancelled &&
        activeRequest.contentVersion == contentVersion) {
      return _joinActiveRequest(
        id,
        cacheKey,
        activeRequest,
        keepAlive,
        priority,
        cancellation,
      );
    }

    final requestState = _ActiveImageRequest(
      keepAlive,
      contentVersion: contentVersion,
      retainedImage: retainedImage,
      priority: priority,
    );
    requestState.addConsumer(cancellation, priority, () {
      if (identical(_activeRequests[cacheKey], requestState)) {
        _activeRequests.remove(cacheKey);
      }
    }, (priority) => _downloadScheduler.reprioritize(requestState, priority));
    final request = _fetchAndCacheImage(
      id,
      requestState,
      fallback: fallback,
      imageUrl: imageUrl,
      fallbackToEndpoint: fallbackToEndpoint,
    );
    _pendingImageRequests.update(
      cacheKey,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    requestState.future = request;
    _activeRequests[cacheKey] = requestState;
    try {
      final bytes = await request;
      return _disposed || cancellation?.isCancelled == true ? null : bytes;
    } finally {
      if (identical(_activeRequests[cacheKey], requestState)) {
        _activeRequests.remove(cacheKey);
      }
      _finishImageRequest(cacheKey);
      requestState.clearConsumers();
    }
  }

  Future<Uint8List?> _fetchAndCacheImage(
    String id,
    _ActiveImageRequest requestState, {
    Uint8List? fallback,
    String? imageUrl,
    bool fallbackToEndpoint = true,
  }) async {
    if (!_canContinue(requestState)) return null;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final image = await _fetchAndCacheFromUrl(id, imageUrl, requestState);
      if (!_canContinue(requestState)) return null;
      if (image != null) return image;
      if (!fallbackToEndpoint) return fallback;
    }

    return _fetchAndCacheFromEndpoint(id, requestState, fallback: fallback);
  }

  Future<Uint8List?> _fetchAndCacheFromUrl(
    String id,
    String imageUrl,
    _ActiveImageRequest requestState,
  ) async {
    try {
      final response = await _downloadScheduler.run<http.Response?>(
        () => _canContinue(requestState)
            ? _getHttpResponse(Uri.parse(imageUrl), requestState.abort)
            : Future<http.Response?>.value(),
        priority: requestState.priority,
        request: requestState,
        cancellation: requestState.abort,
      );
      if (response == null || !_canContinue(requestState)) return null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.bodyBytes.isEmpty) {
          _invalidateSuppliedImageUrl(id, imageUrl);
          return null;
        }
        return await _saveAndPrecacheImage(
          id,
          response.bodyBytes,
          requestState.initialKeepAlive,
          contentVersion: requestState.contentVersion,
          cancellation: requestState.abort,
        );
      }
      _invalidateSuppliedImageUrl(id, imageUrl);
      debugPrint(
        'HTTP error fetching image $id from supplied URL: ${response.statusCode}',
      );
    } catch (_) {
      if (!_canContinue(requestState)) return null;
      _invalidateSuppliedImageUrl(id, imageUrl);
      debugPrint('Network exception fetching image $id from supplied URL.');
    }
    return null;
  }

  void _invalidateSuppliedImageUrl(String id, String url) {
    try {
      invalidateSuppliedImageUrl?.call(id, url);
    } catch (_) {
      // Invalidating a cached URL is best-effort; repository fallback continues.
    }
  }

  Future<Uint8List?> _fetchAndCacheFromEndpoint(
    String id,
    _ActiveImageRequest requestState, {
    Uint8List? fallback,
  }) async {
    try {
      if (!_canContinue(requestState)) return null;
      final imageUrl = await getImageUrl(id);
      if (!_canContinue(requestState)) return null;
      if (imageUrl == null) {
        if (fallback == null) {
          await _saveAndPrecacheImage(
            id,
            Uint8List(0),
            requestState.initialKeepAlive,
            contentVersion: requestState.contentVersion,
            retainedImage: requestState.retainedImage,
            cancellation: requestState.abort,
          );
        }
        return _disposed ? null : fallback;
      }

      final response = await _downloadScheduler.run<http.Response?>(
        () => _canContinue(requestState)
            ? _getHttpResponse(Uri.parse(imageUrl), requestState.abort)
            : Future<http.Response?>.value(),
        priority: requestState.priority,
        request: requestState,
        cancellation: requestState.abort,
      );
      if (response == null || !_canContinue(requestState)) return null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.bodyBytes.isEmpty) {
          if (fallback == null) {
            await _saveAndPrecacheImage(
              id,
              Uint8List(0),
              requestState.initialKeepAlive,
              contentVersion: requestState.contentVersion,
              retainedImage: requestState.retainedImage,
              cancellation: requestState.abort,
            );
          }
          return _disposed ? null : fallback;
        }
        return await _saveAndPrecacheImage(
          id,
          response.bodyBytes,
          requestState.initialKeepAlive,
          contentVersion: requestState.contentVersion,
          retainedImage: requestState.retainedImage,
          cancellation: requestState.abort,
        );
      }

      if (response.statusCode == 404 && fallback == null) {
        await _saveAndPrecacheImage(
          id,
          Uint8List(0),
          requestState.initialKeepAlive,
          contentVersion: requestState.contentVersion,
          retainedImage: requestState.retainedImage,
          cancellation: requestState.abort,
        );
      }
      debugPrint('HTTP error fetching image $id: ${response.statusCode}');
      return _disposed ? null : fallback;
    } catch (error) {
      if (!_canContinue(requestState)) return null;
      if (error is BatchReadFailure &&
          error.status == 404 &&
          fallback == null) {
        await _saveAndPrecacheImage(
          id,
          Uint8List(0),
          requestState.initialKeepAlive,
          contentVersion: requestState.contentVersion,
          retainedImage: requestState.retainedImage,
          cancellation: requestState.abort,
        );
        return null;
      }
      debugPrint('Network exception fetching image $id.');
      return _disposed ? null : fallback;
    }
  }

  Future<void> _promoteKeepAlive(String id) async {
    final cachedImage = await _getByCacheKey(_cacheKey(id));
    if (cachedImage != null && !cachedImage.keepAlive) {
      await _touch(cachedImage, keepAlive: true);
    }
  }

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async {
    await ready;
    if (_disposed) return Uint8List(0);
    final cacheKey = _cacheKey(id);
    final replacementVersion = _issueReplacementVersion(cacheKey);
    try {
      final http.Response response;
      try {
        final scheduled = await _downloadScheduler.run<http.Response?>(
          () => _canFetchRemote
              ? _getHttpResponse(Uri.parse(url), null)
              : Future<http.Response?>.value(),
        );
        if (scheduled == null) return Uint8List(0);
        response = scheduled;
      } catch (_) {
        // The exception can include the full presigned URI. Some callers do
        // not await this cache refresh, so only propagate a sanitized error.
        throw Exception('Failed to override image.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Failed to override image. Status: ${response.statusCode}',
        );
      }
      return await _saveAndPrecacheImage(
        id,
        response.bodyBytes,
        keepAlive,
        replacementVersion: replacementVersion,
      );
    } finally {
      _finishReplacementOperation(cacheKey);
    }
  }

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {
    await ready;
    if (_disposed) return;
    final cacheKey = _cacheKey(id);
    final replacementVersion = _issueReplacementVersion(cacheKey);
    try {
      await _saveAndPrecacheImage(
        id,
        image,
        keepAlive,
        replacementVersion: replacementVersion,
      );
    } finally {
      _finishReplacementOperation(cacheKey);
    }
  }

  // --- ACCESS TRACKING AND PRUNING ---

  Future<void> _touch(ImageEntity entity, {bool? keepAlive}) async {
    final nextKeepAlive = keepAlive == true
        ? const Value<bool>(true)
        : const Value<bool>.absent();
    final nextHits = entity.hits == 0 ? 1 : entity.hits + 1;
    await (db.update(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(entity.cacheKey))).write(
      ImageEntitiesCompanion(
        hits: Value(nextHits),
        keepAlive: nextKeepAlive,
        lastAccessedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Uint8List> _saveAndPrecacheImage(
    String id,
    Uint8List bytes,
    bool keepAlive, {
    int? contentVersion,
    int? replacementVersion,
    ImageEntity? retainedImage,
    ImageRequestCancellation? cancellation,
  }) {
    final cacheKey = _cacheKey(id);
    assert((contentVersion == null) != (replacementVersion == null));
    return _enqueueWrite(cacheKey, () async {
      // A request can outlive logout or an account switch. Return the
      // downloaded bytes to its caller, but never let an old session repopulate
      // the shared byte/database cache after the session has changed.
      if (_disposed ||
          cancellation?.isCancelled == true ||
          (isSessionCurrent != null && !isSessionCurrent!())) {
        return;
      }
      if (contentVersion != null &&
          contentVersion != _contentVersion(cacheKey)) {
        return;
      }
      if (replacementVersion != null &&
          replacementVersion < (_committedReplacementVersions[cacheKey] ?? 0)) {
        return;
      }
      var effectiveKeepAlive = keepAlive;
      if (!keepAlive) {
        final cachedImage = await _getByCacheKey(cacheKey);
        if (cachedImage?.keepAlive == true) {
          // A refresh may replace the retained row it read, but not a newer
          // retained image saved while its download was in flight. Access-only
          // updates do not change image bytes or the expiry time.
          if (retainedImage == null ||
              retainedImage.ttl != cachedImage!.ttl ||
              !listEquals(retainedImage.image, cachedImage.image)) {
            return;
          }
          effectiveKeepAlive = true;
        }
      }
      if (_disposed ||
          cancellation?.isCancelled == true ||
          (isSessionCurrent != null && !isSessionCurrent!())) {
        return;
      }
      await put(
        ImageEntity(
          id: id,
          type: type,
          image: bytes,
          keepAlive: effectiveKeepAlive,
          ttl: _calculateTtl(isNegative: bytes.isEmpty),
          onlySession: false,
          lastAccessedAt: DateTime.now(),
        ),
      );
      if (replacementVersion != null) {
        _committedReplacementVersions[cacheKey] = replacementVersion;
        _imageContentVersions[cacheKey] = _contentVersion(cacheKey) + 1;
      }
    }).then(
      (_) =>
          _disposed || cancellation?.isCancelled == true ? Uint8List(0) : bytes,
    );
  }

  DateTime _calculateTtl({required bool isNegative}) {
    final ttl = isNegative
        ? negativeTtlDuration
        : ttlDuration ?? const Duration(days: 7);
    return DateTime.now().add(ttl);
  }

  Future<void> _enqueuePrune() {
    final next = _pruneQueue.then<void>((_) => _pruneCacheLimits());
    _pruneQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        debugPrint('Image cache pruning failed: $error');
      },
    );
    return next;
  }

  Future<void> _pruneCacheLimits() async {
    final rows = await (db.select(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).get();
    if (rows.isEmpty) return;

    final now = DateTime.now();
    final protectedKeys = <String>{
      ..._activeWatchers.keys,
      ..._activeRequests.keys,
    };
    final removable = rows
        .where((row) => !row.keepAlive && !protectedKeys.contains(row.cacheKey))
        .toList();
    final keysToDelete = <String>{
      for (final row in removable)
        if (row.ttl.isBefore(now)) row.cacheKey,
    };

    if (maxItems != null) {
      final remaining = removable
          .where((row) => !keysToDelete.contains(row.cacheKey))
          .toList();
      final excess = remaining.length - maxItems!;
      if (excess > 0) {
        remaining.sort(_compareEvictionOrder);
        keysToDelete.addAll(remaining.take(excess).map((row) => row.cacheKey));
      }
    }

    if (keysToDelete.isEmpty) return;
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keysToDelete.toList()))).go();
    for (final row in rows) {
      if (keysToDelete.contains(row.cacheKey)) {
        _removeMemoryBytes(row.id);
      }
    }
  }

  int _compareEvictionOrder(ImageDb left, ImageDb right) {
    final leftAccess =
        left.lastAccessedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rightAccess =
        right.lastAccessedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final accessComparison = leftAccess.compareTo(rightAccess);
    if (accessComparison != 0) return accessComparison;

    final hitComparison = left.hits.compareTo(right.hits);
    if (hitComparison != 0) return hitComparison;
    return left.cacheKey.compareTo(right.cacheKey);
  }
}

// --- PROVIDERS ---

final imageDownloadSchedulerProvider = Provider<ImageDownloadScheduler>((ref) {
  watchSession(ref);
  return ImageDownloadScheduler();
});

@Riverpod(keepAlive: true)
IImageRepository groupProfileRepo(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.group,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) => _resolveImageUrl(ref, BatchReadKind.groupImage, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.groupImage, id),
    maxItems: 400,
    ttlDuration: const Duration(days: 7),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
IImageRepository groupProfileSmallRepo(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.groupSmall,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) =>
        _resolveImageUrl(ref, BatchReadKind.groupImageSmall, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.groupImageSmall, id),
    maxItems: 400,
    ttlDuration: const Duration(days: 7),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
IImageRepository groupPinImageRepo(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.groupPin,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) => _resolveImageUrl(ref, BatchReadKind.groupPinImage, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.groupPinImage, id),
    maxItems: 200,
    ttlDuration: const Duration(days: 30),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
IImageRepository userImageSmallRepo(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.userSmall,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) =>
        _resolveImageUrl(ref, BatchReadKind.userImageSmall, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.userImageSmall, id),
    maxItems: 2000,
    ttlDuration: const Duration(days: 7),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
IImageRepository userImageRepo(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.user,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) => _resolveImageUrl(ref, BatchReadKind.userImage, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.userImage, id),
    maxItems: 200,
    ttlDuration: const Duration(days: 7),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
IImageRepository pinImageRepository(Ref ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.pin,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) => _resolveImageUrl(ref, BatchReadKind.pinImage, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.pinImage, id),
    maxItems: 800,
    ttlDuration: const Duration(days: 14),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

final pinThumbnailRepositoryProvider = Provider<IImageRepository>((ref) {
  final repository = ImageRepository(
    downloadScheduler: ref.watch(imageDownloadSchedulerProvider),
    db: ref.watch(accountDatabaseProvider),
    type: ImageType.pinThumbnail,
    isSessionCurrent: _sessionGuard(ref),
    getImageUrl: (id) =>
        _resolveImageUrl(ref, BatchReadKind.pinImageThumbnail, id),
    getSuppliedImageUrl: (id) => ref
        .read(suppliedImageUrlRegistryProvider)
        .lookup(BatchReadKind.pinImageThumbnail, id),
    invalidateSuppliedImageUrl: (id, url) => ref
        .read(suppliedImageUrlRegistryProvider)
        .invalidate(BatchReadKind.pinImageThumbnail, id, url),
    maxItems: 800,
    maxMemoryCacheItems: 128,
    ttlDuration: const Duration(days: 14),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

bool Function() _sessionGuard(Ref ref) {
  final session = watchSession(ref);
  return () => isCurrentSession(ref, session);
}

Future<String?> _resolveImageUrl(Ref ref, BatchReadKind kind, String id) async {
  final result = await ref
      .read(batchReadCoalescerProvider)
      .readKey(BatchReadKey(kind, id));
  return result.imageUrl;
}
