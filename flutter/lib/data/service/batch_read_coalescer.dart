import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

/// The resource kinds supported by the authenticated batch-read endpoint.
enum BatchReadKind {
  pinImage,
  userImageSmall,
  userImage,
  groupImageSmall,
  groupImage,
  groupPinImage,
  user,
  pinLikes,
}

/// A single, de-duplicatable resource read.
class BatchReadKey {
  const BatchReadKey(this.kind, this.id);

  final BatchReadKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is BatchReadKey && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

BatchReadItemKindEnum batchItemKind(BatchReadKind kind) => switch (kind) {
  BatchReadKind.pinImage => BatchReadItemKindEnum.pinImage,
  BatchReadKind.userImageSmall => BatchReadItemKindEnum.userImageSmall,
  BatchReadKind.userImage => BatchReadItemKindEnum.userImage,
  BatchReadKind.groupImageSmall => BatchReadItemKindEnum.groupImageSmall,
  BatchReadKind.groupImage => BatchReadItemKindEnum.groupImage,
  BatchReadKind.groupPinImage => BatchReadItemKindEnum.groupPinImage,
  BatchReadKind.user => BatchReadItemKindEnum.user,
  BatchReadKind.pinLikes => BatchReadItemKindEnum.pinLikes,
};

BatchReadResultKindEnum batchResultKind(BatchReadItemKindEnum kind) =>
    switch (kind) {
      BatchReadItemKindEnum.pinImage => BatchReadResultKindEnum.pinImage,
      BatchReadItemKindEnum.userImageSmall =>
        BatchReadResultKindEnum.userImageSmall,
      BatchReadItemKindEnum.userImage => BatchReadResultKindEnum.userImage,
      BatchReadItemKindEnum.groupImageSmall =>
        BatchReadResultKindEnum.groupImageSmall,
      BatchReadItemKindEnum.groupImage => BatchReadResultKindEnum.groupImage,
      BatchReadItemKindEnum.groupPinImage =>
        BatchReadResultKindEnum.groupPinImage,
      BatchReadItemKindEnum.user => BatchReadResultKindEnum.user,
      BatchReadItemKindEnum.pinLikes => BatchReadResultKindEnum.pinLikes,
      _ => throw ArgumentError.value(kind, 'kind'),
    };

BatchReadKind batchReadKind(BatchReadResultKindEnum kind) => switch (kind) {
  BatchReadResultKindEnum.pinImage => BatchReadKind.pinImage,
  BatchReadResultKindEnum.userImageSmall => BatchReadKind.userImageSmall,
  BatchReadResultKindEnum.userImage => BatchReadKind.userImage,
  BatchReadResultKindEnum.groupImageSmall => BatchReadKind.groupImageSmall,
  BatchReadResultKindEnum.groupImage => BatchReadKind.groupImage,
  BatchReadResultKindEnum.groupPinImage => BatchReadKind.groupPinImage,
  BatchReadResultKindEnum.user => BatchReadKind.user,
  BatchReadResultKindEnum.pinLikes => BatchReadKind.pinLikes,
  _ => throw ArgumentError.value(kind, 'kind'),
};

typedef BatchReadTransport = Future<List<BatchReadResult>> Function(
  List<BatchReadItem> items,
);

/// Adapts the generated client to the small transport used by the coalescer.
class BatchReadApiTransport {
  BatchReadApiTransport(this._api);

  final BatchApi _api;

  Future<List<BatchReadResult>> call(List<BatchReadItem> items) async =>
      (await _api.batchRead(BatchReadRequest(requests: items)))?.results ?? [];
}

class BatchReadFailure implements Exception {
  const BatchReadFailure(this.key, this.status);

  final BatchReadKey key;
  final int status;

  @override
  String toString() =>
      'Batch read failed for ${key.kind.name}:${key.id} ($status)';
}

class BatchReadDisposedException implements Exception {
  const BatchReadDisposedException();
}

/// Coalesces independent cache misses for the lifetime of one authenticated
/// API client. Results deliberately are not cached here: each repository owns
/// its own cache policy, including negative and stale-value behavior.
class BatchReadCoalescer {
  BatchReadCoalescer({
    required BatchReadTransport read,
    this.window = const Duration(milliseconds: 12),
    this.maxConcurrentBatches = 2,
    this.onResult,
  }) : _read = read;

  static const maxItemsPerRequest = 100;

  final BatchReadTransport _read;
  final Duration window;
  final int maxConcurrentBatches;
  final void Function(BatchReadKey key, BatchReadResult result)? onResult;
  final Map<BatchReadKey, Completer<BatchReadResult>> _requests = {};
  final Map<BatchReadKey, Completer<BatchReadResult>> _pending = {};
  final Set<Completer<BatchReadResult>> _inFlight = {};
  Timer? _timer;
  bool _disposed = false;

  Future<BatchReadResult> readKey(BatchReadKey key) {
    if (_disposed)
      return Future<BatchReadResult>.error(const BatchReadDisposedException());
    final existing = _requests[key];
    if (existing != null) return existing.future;

    final completer = Completer<BatchReadResult>();
    _requests[key] = completer;
    _pending[key] = completer;
    _timer ??= Timer(window, _flush);
    return completer.future;
  }

  void _flush() {
    _timer = null;
    if (_disposed || _pending.isEmpty) return;

    final batch = Map<BatchReadKey, Completer<BatchReadResult>>.from(_pending);
    _pending.clear();
    _inFlight.addAll(batch.values);
    final entries = batch.entries.toList(growable: false);
    final chunks = <List<MapEntry<BatchReadKey, Completer<BatchReadResult>>>>[];
    for (var index = 0; index < entries.length; index += maxItemsPerRequest) {
      chunks.add(
        entries.sublist(
          index,
          (index + maxItemsPerRequest).clamp(0, entries.length),
        ),
      );
    }
    unawaited(_runChunks(chunks));
  }

  Future<void> _runChunks(
    List<List<MapEntry<BatchReadKey, Completer<BatchReadResult>>>> chunks,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (!_disposed && next < chunks.length) {
        final chunk = chunks[next++];
        await _readChunk(chunk);
      }
    }

    await Future.wait(
      List.generate(
        maxConcurrentBatches.clamp(1, chunks.length),
        (_) => worker(),
      ),
    );
  }

  Future<void> _readChunk(
    List<MapEntry<BatchReadKey, Completer<BatchReadResult>>> chunk,
  ) async {
    try {
      final results = await _read([
        for (final entry in chunk)
          BatchReadItem(kind: batchItemKind(entry.key.kind), id: entry.key.id),
      ]);
      if (_disposed) return;
      final resultByKey = <BatchReadKey, BatchReadResult>{
        for (final result in results)
          BatchReadKey(batchReadKind(result.kind), result.id): result,
      };
      for (final entry in chunk) {
        final result = resultByKey[entry.key];
        if (result == null) {
          entry.value.completeError(BatchReadFailure(entry.key, 502));
        } else if (result.status >= 200 && result.status < 300) {
          onResult?.call(entry.key, result);
          entry.value.complete(result);
        } else {
          entry.value.completeError(BatchReadFailure(entry.key, result.status));
        }
        if (identical(_requests[entry.key], entry.value)) {
          _requests.remove(entry.key);
        }
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        for (final entry in chunk) {
          entry.value.completeError(error, stackTrace);
          if (identical(_requests[entry.key], entry.value)) {
            _requests.remove(entry.key);
          }
        }
      }
    } finally {
      _inFlight.removeAll(chunk.map((entry) => entry.value));
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    const error = BatchReadDisposedException();
    for (final completer in [..._pending.values, ..._inFlight]) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
    _inFlight.clear();
    _requests.clear();
  }
}

/// A small LRU registry for URLs supplied with sync/list DTOs. It has no byte
/// data and is disposed with the authenticated API session.
class SuppliedImageUrlRegistry {
  SuppliedImageUrlRegistry({this.maxEntries = 1000});

  final int maxEntries;
  final LinkedHashMap<BatchReadKey, String> _urls = LinkedHashMap();

  void register(BatchReadKind kind, String id, String? url) {
    if (url == null || url.isEmpty) return;
    final key = BatchReadKey(kind, id);
    _urls.remove(key);
    _urls[key] = url;
    while (_urls.length > maxEntries) {
      _urls.remove(_urls.keys.first);
    }
  }

  String? lookup(BatchReadKind kind, String id) {
    final key = BatchReadKey(kind, id);
    final url = _urls.remove(key);
    if (url != null) _urls[key] = url;
    return url;
  }
}

final batchReadCoalescerProvider = Provider<BatchReadCoalescer>((ref) {
  final transport = BatchReadApiTransport(
    BatchApi(ref.watch(openApiConfigProvider)),
  );
  final suppliedUrls = ref.watch(suppliedImageUrlRegistryProvider);
  final coalescer = BatchReadCoalescer(
    read: transport.call,
    onResult: (key, result) =>
        suppliedUrls.register(key.kind, key.id, result.imageUrl),
  );
  ref.onDispose(coalescer.dispose);
  return coalescer;
});

final suppliedImageUrlRegistryProvider = Provider<SuppliedImageUrlRegistry>((
  ref,
) {
  // A URL is an authenticated, short-lived credential. Rebuild the registry
  // whenever the account session changes so it cannot cross account bounds.
  ref.watch(
    globalDataServiceProvider.select(
      (data) => (userId: data.userId, refreshToken: data.refreshToken),
    ),
  );
  return SuppliedImageUrlRegistry();
});

void registerPinImageUrl(Ref ref, PinWithOptionalImageDto pin) {
  if (pin.image == null || pin.image!.isEmpty) return;
  ref
      .read(suppliedImageUrlRegistryProvider)
      .register(BatchReadKind.pinImage, pin.id, pin.image);
}

void registerGroupImageUrls(Ref ref, GroupDto group) {
  if (group.profileImage == null &&
      group.profileImageSmall == null &&
      group.pinImage == null) {
    return;
  }
  final registry = ref.read(suppliedImageUrlRegistryProvider);
  registry.register(BatchReadKind.groupImage, group.id, group.profileImage);
  registry.register(
    BatchReadKind.groupImageSmall,
    group.id,
    group.profileImageSmall,
  );
  registry.register(BatchReadKind.groupPinImage, group.id, group.pinImage);
}
