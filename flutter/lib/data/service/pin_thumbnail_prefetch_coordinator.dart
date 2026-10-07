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

    _removeOwner(owner, retain: requests.keys.toSet());
    for (final entry in requests.entries) {
      if (entry.key.isEmpty) continue;

      final active = _activeById[entry.key];
      final request = active != null && !active.cancellation.isCancelled
          ? active
          : _queuedById[entry.key];
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
      dropped.cancellation.cancel();
    }
    _drain();
  }

  void cancelWindow(Object owner) {
    if (_disposed) return;
    _removeOwner(owner);
    _drain();
  }

  void _removeOwner(Object owner, {Set<String> retain = const {}}) {
    for (final request in _activeById.values.toList(growable: false)) {
      if (retain.contains(request.pinId)) continue;
      request.warmers.remove(owner);
      if (request.warmers.isEmpty) {
        request.cancellation.cancel();
      }
    }

    for (final request in _queuedById.values.toList(growable: false)) {
      if (retain.contains(request.pinId)) continue;
      request.warmers.remove(owner);
      if (request.warmers.isEmpty) {
        request.cancellation.cancel();
        _queuedById.remove(request.pinId);
        _queue.remove(request);
      }
    }
  }

  void _drain() {
    final limit = maxConcurrentRequests.clamp(1, 8);
    while (!_disposed && _activeById.length < limit && _queue.isNotEmpty) {
      _PinThumbnailRequest? request;
      final queuedCount = _queue.length;
      for (var index = 0; index < queuedCount; index++) {
        final candidate = _queue.removeFirst();
        if (candidate.warmers.isEmpty || candidate.cancellation.isCancelled) {
          if (identical(_queuedById[candidate.pinId], candidate)) {
            _queuedById.remove(candidate.pinId);
          }
          continue;
        }
        if (_activeById.containsKey(candidate.pinId)) {
          _queue.addLast(candidate);
          continue;
        }
        request = candidate;
        break;
      }
      if (request == null) break;
      _queuedById.remove(request.pinId);
      _activeById[request.pinId] = request;
      unawaited(_loadAndWarm(request));
    }
  }

  Future<void> _loadAndWarm(_PinThumbnailRequest request) async {
    try {
      final bytes = await repository.fetchImage(
        request.pinId,
        false,
        priority: ImageRequestPriority.background,
        cancellation: request.cancellation,
      );
      if (bytes == null ||
          bytes.isEmpty ||
          _disposed ||
          request.cancellation.isCancelled) {
        return;
      }

      final warmed = <Object, PinThumbnailWarmer>{};
      while (!request.cancellation.isCancelled) {
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
    for (final request in _queue) {
      request.cancellation.cancel();
    }
    _queue.clear();
    _queuedById.clear();
    for (final request in _activeById.values) {
      request.warmers.clear();
      request.cancellation.cancel();
    }
    _activeById.clear();
  }
}

class _PinThumbnailRequest {
  _PinThumbnailRequest(this.pinId);

  final String pinId;
  final Map<Object, PinThumbnailWarmer> warmers = {};
  final ImageRequestCancellation cancellation = ImageRequestCancellation();
}

final pinThumbnailPrefetchCoordinatorProvider =
    Provider<PinThumbnailPrefetchCoordinator>((ref) {
      final coordinator = PinThumbnailPrefetchCoordinator(
        repository: ref.watch(pinThumbnailRepositoryProvider),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
