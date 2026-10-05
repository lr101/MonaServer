import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PinThumbnailWarmer = Future<void> Function(Uint8List bytes);

/// Shares bounded thumbnail byte loads across feeds and profile galleries.
///
/// Downloads go through the session's pin thumbnail repository, so visible
/// images and look-ahead work share URL resolution, request de-duplication,
/// local byte storage, and eviction policy. UI owners may attach a warmer to
/// put the decoded image into Flutter's image cache before it becomes visible.
class PinThumbnailPrefetchCoordinator {
  PinThumbnailPrefetchCoordinator({
    required this.repository,
    this.maxConcurrentRequests = 2,
    this.maxQueuedRequests = 36,
  });

  final IImageRepository repository;
  final int maxConcurrentRequests;
  final int maxQueuedRequests;

  final Queue<_PinThumbnailRequest> _queue = Queue<_PinThumbnailRequest>();
  final Map<String, _PinThumbnailRequest> _queuedById = {};
  final Map<String, _PinThumbnailRequest> _activeById = {};
  bool _disposed = false;

  /// Replaces one screen's look-ahead window while preserving other screens'
  /// requests. Requests for the same pin share one repository load.
  void updateWindow(Object owner, Map<String, PinThumbnailWarmer> requests) {
    if (_disposed) return;

    _removeOwner(owner);
    for (final entry in requests.entries) {
      if (entry.key.isEmpty) continue;

      final request = _activeById[entry.key] ?? _queuedById[entry.key];
      if (request != null) {
        request.warmers[owner] = entry.value;
        continue;
      }

      final next = _PinThumbnailRequest(entry.key)
        ..warmers[owner] = entry.value;
      _queue.addLast(next);
      _queuedById[entry.key] = next;
    }

    while (_queue.length > maxQueuedRequests) {
      final dropped = _queue.removeFirst();
      if (identical(_queuedById[dropped.pinId], dropped)) {
        _queuedById.remove(dropped.pinId);
      }
    }
    _drain();
  }

  void cancelWindow(Object owner) {
    if (_disposed) return;
    _removeOwner(owner);
  }

  void _removeOwner(Object owner) {
    for (final request in _activeById.values) {
      request.warmers.remove(owner);
    }

    for (final request in _queuedById.values.toList(growable: false)) {
      request.warmers.remove(owner);
      if (request.warmers.isEmpty) {
        _queuedById.remove(request.pinId);
        _queue.remove(request);
      }
    }
  }

  void _drain() {
    final limit = maxConcurrentRequests.clamp(1, 8);
    while (!_disposed && _activeById.length < limit && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      if (request.warmers.isEmpty) continue;
      _queuedById.remove(request.pinId);
      _activeById[request.pinId] = request;
      unawaited(_loadAndWarm(request));
    }
  }

  Future<void> _loadAndWarm(_PinThumbnailRequest request) async {
    try {
      final bytes = await repository.fetchImage(request.pinId, false);
      if (bytes == null || bytes.isEmpty || _disposed) return;

      final warmed = <Object, PinThumbnailWarmer>{};
      while (true) {
        final pendingWarmers = request.warmers.entries
            .where((entry) => !identical(warmed[entry.key], entry.value))
            .toList(growable: false);
        if (pendingWarmers.isEmpty) break;

        await Future.wait<void>(
          pendingWarmers.map((entry) async {
            try {
              await entry.value(bytes);
            } catch (_) {
              // Decode and cache warming are best-effort; visible tiles retry.
            }
            warmed[entry.key] = entry.value;
          }),
        );
      }
    } catch (_) {
      // Prefetch failures must not affect visible image loads or page assembly.
    } finally {
      if (identical(_activeById[request.pinId], request)) {
        _activeById.remove(request.pinId);
      }
      _drain();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    _queuedById.clear();
    for (final request in _activeById.values) {
      request.warmers.clear();
    }
  }
}

class _PinThumbnailRequest {
  _PinThumbnailRequest(this.pinId);

  final String pinId;
  final Map<Object, PinThumbnailWarmer> warmers = {};
}

final pinThumbnailPrefetchCoordinatorProvider =
    Provider<PinThumbnailPrefetchCoordinator>((ref) {
      final coordinator = PinThumbnailPrefetchCoordinator(
        repository: ref.watch(pinThumbnailRepositoryProvider),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
