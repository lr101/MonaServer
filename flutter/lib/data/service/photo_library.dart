import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class PhotoScope {
  const PhotoScope({this.userId, this.groupId});
  final String? userId;
  final String? groupId;
  bool contains(PinEntity pin, PinPhotoDto photo) =>
      (groupId == null || pin.groupId == groupId) &&
      (userId == null || photo.contributorId == userId);
  @override
  bool operator ==(Object other) =>
      other is PhotoScope && userId == other.userId && groupId == other.groupId;
  @override
  int get hashCode => Object.hash(userId, groupId);
}

class GalleryPhotoRecord {
  const GalleryPhotoRecord(this.pin, this.photo);
  final PinEntity pin;
  final PinPhotoDto photo;
}

class GalleryPhotoPage {
  const GalleryPhotoPage({required this.items, this.nextCursor});
  final List<GalleryPhotoRecord> items;
  final String? nextCursor;
}

class PhotoGallerySnapshot {
  const PhotoGallerySnapshot(
    this.photos, {
    this.error,
    this.refreshing = false,
    this.loaded = false,
  });
  final List<PinPhotoDto> photos;
  final Object? error;
  final bool refreshing;
  final bool loaded;
}

/// One session owns photo identity, persisted last-good metadata, and all read
/// coordination. PinEntity is only a compatibility projection for existing UI.
class PhotoLibrary {
  PhotoLibrary({
    required this.histories,
    required this.pins,
    required this.fetchPage,
    required this.fetchHistory,
    required this.resolvePhotos,
    required this.publish,
    this.revokePinUrls,
  });
  final IPinPhotoHistoryRepository histories;
  final IPinRepository pins;
  final Future<GalleryPhotoPage> Function(PhotoScope, String?) fetchPage;
  final Future<List<PinPhotoDto>> Function(String) fetchHistory;
  final Future<Map<String, PinPhotoDto?>> Function(List<String>) resolvePhotos;
  final void Function(String, List<PinPhotoDto>) publish;
  final void Function(Iterable<String>)? revokePinUrls;
  final _changes = StreamController<void>.broadcast(sync: true);
  final Map<String, PinPhotoDto> _photos = {};
  final Map<String, PinEntity> _pins = {};
  final Map<PhotoScope, Set<String>> _galleries = {};
  final Map<PhotoScope, Object> _errors = {};
  final Set<PhotoScope> _scopes = {};
  // Sync can discover updates for the map/feed without mounting a gallery.
  // Keep failed scopes until a successful resume retry discovers those photos.
  final Set<PhotoScope> _failedScopes = {};
  final Map<PhotoScope, int> _galleryWatchers = {};
  final Set<String> _activeHistories = {};
  final Map<String, int> _historyWatchers = {};
  final Map<PhotoScope, Future<void>> _galleryRequests = {};
  final Map<String, Future<List<PinPhotoDto>>> _historyRequests = {};
  final Map<String, Completer<PinPhotoDto?>> _urlRequests = {};
  final Map<String, StreamController<void>> _pinEvents = {};
  final Map<PhotoScope, StreamController<void>> _scopeEvents = {};
  final Map<String, int> _mutations = {};
  final Map<String, int> _deletedPins = {};
  final Map<String, int> _removedGroups = {};
  final Map<String, int> _restoredGroups = {};
  final Map<String, Object> _historyErrors = {};
  final Map<String, int> _metadataUpdates = {};
  final Set<String> _urlsInFlight = {};
  int _revision = 0;
  bool _closed = false;
  Future<void>? _hydration;
  Future<void> _writes = Future.value();
  bool _urlScheduled = false;
  Stream<void> get changes => _changes.stream;
  Stream<void> _changesForPin(String pinId) => _pinEvents
      .putIfAbsent(pinId, () => StreamController<void>.broadcast(sync: true))
      .stream;
  Stream<void> _changesForScope(PhotoScope scope) => _scopeEvents
      .putIfAbsent(scope, () => StreamController<void>.broadcast(sync: true))
      .stream;

  void _retainGallery(PhotoScope scope) {
    _galleryWatchers.update(scope, (count) => count + 1, ifAbsent: () => 1);
    _scopes.add(scope);
  }

  void _releaseGallery(PhotoScope scope) {
    final count = _galleryWatchers[scope] ?? 0;
    if (count > 1) {
      _galleryWatchers[scope] = count - 1;
      return;
    }
    _galleryWatchers.remove(scope);
    _scopes.remove(scope);
    final events = _scopeEvents.remove(scope);
    if (events != null) unawaited(events.close());
  }

  void _retainHistory(String pinId) {
    _historyWatchers.update(pinId, (count) => count + 1, ifAbsent: () => 1);
    _activeHistories.add(pinId);
  }

  void _releaseHistory(String pinId) {
    final count = _historyWatchers[pinId] ?? 0;
    if (count > 1) {
      _historyWatchers[pinId] = count - 1;
      return;
    }
    _historyWatchers.remove(pinId);
    _activeHistories.remove(pinId);
    final events = _pinEvents.remove(pinId);
    if (events != null) unawaited(events.close());
  }

  Set<PhotoScope> _scopesMatching(Iterable<PinPhotoDto> photos) {
    final matching = <PhotoScope>{};
    for (final photo in photos) {
      final pin = _pins[photo.pinId];
      if (pin == null) continue;
      for (final scope in _scopes) {
        if (scope.contains(pin, photo)) matching.add(scope);
      }
    }
    return matching;
  }

  void _notify({
    Iterable<String> pinIds = const [],
    Iterable<PhotoScope> scopes = const [],
    bool allGalleries = false,
  }) {
    if (_closed) return;
    final changedPins = pinIds.toSet();
    if (changedPins.isNotEmpty || allGalleries) _changes.add(null);
    for (final pinId in changedPins) {
      _pinEvents[pinId]?.add(null);
    }
    final changedScopes = allGalleries ? _scopes : scopes.toSet();
    for (final scope in changedScopes) {
      _scopeEvents[scope]?.add(null);
    }
  }

  Future<void> _persist(Map<String, List<PinPhotoDto>> data) {
    final write = _writes.then((_) async {
      if (!_closed) {
        await histories.putMultiple({
          for (final id in data.keys) id: history(id),
        });
      }
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> hydrate() => _hydration ??= _hydrate();
  Future<void> _hydrate() async {
    final started = _revision;
    final savedPins = await pins.getAll();
    if (_closed) return;
    final saved = await histories.getMultiple(savedPins.map((p) => p.pinId));
    if (_closed) return;
    for (final pin in savedPins) {
      if ((_deletedPins[pin.pinId] ?? 0) <= started &&
          !_removedGroups.containsKey(pin.groupId)) {
        _pins.putIfAbsent(pin.pinId, () => pin);
      }
    }
    final changedPins = <String>{};
    for (final item in saved.entries) {
      for (final photo in item.value.photos) {
        if ((_deletedPins[photo.pinId] ?? 0) <= started &&
            _pins.containsKey(photo.pinId) &&
            (_mutations[photo.id] ?? 0) <= started) {
          _photos.putIfAbsent(photo.id, () => photo);
          changedPins.add(photo.pinId);
        }
      }
      publish(item.key, history(item.key));
    }
    _notify(
      pinIds: changedPins,
      scopes: _scopesMatching([for (final id in changedPins) ...history(id)]),
    );
  }

  PinEntity? parent(String pinId) => _pins[pinId];
  List<PinPhotoDto> history(String pinId) =>
      _photos.values.where((p) => p.pinId == pinId).toList()
        ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  PhotoGallerySnapshot gallery(PhotoScope scope) {
    final photos =
        _photos.values.where((p) {
          final pin = _pins[p.pinId];
          return pin != null && scope.contains(pin, p);
        }).toList()..sort((a, b) {
          final date = b.observedAt.compareTo(a.observedAt);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });
    return PhotoGallerySnapshot(
      List.unmodifiable(photos),
      error: _errors[scope],
      refreshing: _galleryRequests.containsKey(scope),
      loaded: _galleries.containsKey(scope),
    );
  }

  List<PinEntity> entries(PhotoScope scope) =>
      gallery(scope).photos.map((photo) {
        final pin = _pins[photo.pinId]!;
        return photo.isOriginal ? pin : pin.withPhotoUpdate(photo);
      }).toList();

  Stream<PhotoGallerySnapshot> watchGallery(PhotoScope scope) {
    late StreamController<PhotoGallerySnapshot> stream;
    StreamSubscription<void>? sub;
    stream = StreamController(
      onListen: () {
        // Install the subscription before local hydration or network publication.
        _retainGallery(scope);
        sub = _changesForScope(scope).listen((_) {
          if (!stream.isClosed) stream.add(gallery(scope));
        });
        stream.add(gallery(scope));
        unawaited(() async {
          await hydrate();
          if (_closed) return;
          stream.add(gallery(scope));
          await refreshGallery(scope);
        }());
      },
      onCancel: () async {
        await sub?.cancel();
        _releaseGallery(scope);
      },
    );
    return stream.stream;
  }

  Future<void> refreshGallery(PhotoScope scope) =>
      _galleryRequests[scope] ??= _refreshGallery(scope).whenComplete(() {
        _galleryRequests.remove(scope);
        _notify(scopes: [scope]);
      });
  Future<void> _refreshGallery(PhotoScope scope) async {
    final started = _revision;
    await hydrate();
    if (_closed) return;
    try {
      final records = <GalleryPhotoRecord>[];
      String? cursor;
      final seen = <String>{};
      do {
        final page = await fetchPage(scope, cursor);
        if (_closed) return;
        records.addAll(page.items);
        cursor = page.nextCursor;
        if (cursor != null && cursor.isNotEmpty && !seen.add(cursor)) {
          throw StateError('Repeated gallery cursor');
        }
      } while (cursor != null && cursor.isNotEmpty);
      final ids = records.map((r) => r.photo.id).toSet();
      final version = ++_revision;
      for (final photo in _photos.values) {
        final pin = _pins[photo.pinId];
        if (pin != null &&
            scope.contains(pin, photo) &&
            (_mutations[photo.id] ?? 0) > started) {
          ids.add(photo.id);
        }
      }
      final removed = _photos.values.where((p) {
        final pin = _pins[p.pinId];
        return pin != null &&
            scope.contains(pin, p) &&
            pin.lastSynced != null &&
            !ids.contains(p.id) &&
            (_mutations[p.id] ?? 0) <= started;
      }).toList();
      final changedScopes = _scopesMatching([
        ...removed,
        for (final record in records) record.photo,
      ])..add(scope);
      final affected = <String>{for (final p in removed) p.pinId};
      for (final p in removed) {
        _photos.remove(p.id);
        _mutations[p.id] = version;
      }
      for (final record in records) {
        if ((_deletedPins[record.pin.pinId] ?? 0) > started ||
            (_removedGroups[record.pin.groupId] ?? 0) > started ||
            (_mutations[record.photo.id] ?? 0) > started) {
          continue;
        }
        _pins[record.pin.pinId] = record.pin;
        affected.add(record.pin.pinId);
        _photos[record.photo.id] = record.photo;
        _mutations[record.photo.id] = version;
        _historyErrors.remove(record.pin.pinId);
      }
      _galleries[scope] = ids;
      _errors.remove(scope);
      _failedScopes.remove(scope);
      for (final id in affected) {
        _metadataUpdates[id] = version;
        publish(id, history(id));
      }
      _notify(pinIds: affected, scopes: changedScopes);
      if (_closed) return;
      await pins.putMultiple(
        _pins.values.where((p) => affected.contains(p.pinId)).toList(),
      );
      if (_closed) return;
      await _persist({for (final id in affected) id: history(id)});
    } catch (error) {
      if (_closed) return;
      _errors[scope] = error;
      final changedPins = <String>{};
      if (error is ApiException && (error.code == 403 || error.code == 404)) {
        _failedScopes.remove(scope);
        final affected = _photos.values
            .where((photo) {
              final pin = _pins[photo.pinId];
              return pin != null && scope.contains(pin, photo);
            })
            .map((photo) => photo.pinId)
            .toSet();
        changedPins.addAll(affected);
        if (scope.groupId case final String groupId) {
          await removeGroup(groupId);
        } else {
          await removePins(affected);
        }
        _galleries[scope] = {};
      } else {
        _failedScopes.add(scope);
      }
      _notify(
        pinIds: changedPins,
        scopes: [
          scope,
          ..._scopesMatching([for (final id in changedPins) ...history(id)]),
        ],
        allGalleries: changedPins.isNotEmpty,
      );
    }
  }

  Future<List<PinPhotoDto>> refreshHistory(String pinId) =>
      _historyRequests[pinId] ??= _refreshHistory(pinId).whenComplete(() {
        _historyRequests.remove(pinId);
      });
  Future<List<PinPhotoDto>> _refreshHistory(String pinId) async {
    final started = _revision;
    try {
      final photos = await fetchHistory(pinId);
      if (_closed || (_deletedPins[pinId] ?? 0) > started) return [];
      _historyErrors.remove(pinId);
      final previous = history(pinId);
      final accepted = {
        for (final p in previous)
          if ((_mutations[p.id] ?? 0) > started) p.id: p,
      };
      _photos.removeWhere((_, p) => p.pinId == pinId);
      final version = ++_revision;
      for (final p in photos) {
        if ((_mutations[p.id] ?? 0) <= started) {
          _photos[p.id] = p;
          _mutations[p.id] = version;
        }
      }
      _photos.addAll(accepted);
      final result = history(pinId);
      _metadataUpdates[pinId] = version;
      publish(pinId, result);
      _notify(
        pinIds: [pinId],
        scopes: _scopesMatching([...previous, ...photos]),
      );
      await _persist({pinId: result});
      return result;
    } catch (error) {
      if (_closed || (_deletedPins[pinId] ?? 0) > started) return [];
      // A more recent authorized read/upload already recovered this pin. Its
      // result wins over a delayed failure, including an obsolete 403/404.
      if ((_metadataUpdates[pinId] ?? 0) > started) return history(pinId);
      if (!_closed) {
        _historyErrors[pinId] = error;
        if (error is ApiException && (error.code == 403 || error.code == 404)) {
          await removePins([pinId]);
        }
        _notify(pinIds: [pinId]);
      }
      rethrow;
    }
  }

  Stream<List<PinPhotoDto>> watchHistory(String pinId) {
    late StreamController<List<PinPhotoDto>> stream;
    StreamSubscription<void>? sub;
    stream = StreamController(
      onListen: () {
        _retainHistory(pinId);
        sub = _changesForPin(pinId).listen((_) {
          final error = _historyErrors[pinId];
          if (error != null) {
            stream.addError(error);
          } else {
            stream.add(history(pinId));
          }
        });
        unawaited(() async {
          await hydrate();
          if (_closed) return;
          if (history(pinId).isNotEmpty) stream.add(history(pinId));
          try {
            await refreshHistory(pinId);
          } catch (e, s) {
            if (!_closed) stream.addError(e, s);
          }
        }());
      },
      onCancel: () async {
        await sub?.cancel();
        _releaseHistory(pinId);
      },
    );
    return stream.stream;
  }

  Future<void> ingestOriginals(
    Iterable<PinWithOptionalImageDto> originals,
  ) async {
    await hydrate();
    if (_closed) return;
    final affected = <String>{};
    final previousPhotos = <PinPhotoDto>[];
    for (final dto in originals) {
      final pin = PinEntity.fromDto(dto, false);
      final previousPhoto = _photos[dto.id];
      if (previousPhoto != null) previousPhotos.add(previousPhoto);
      _pins[dto.id] = pin;
      _photos[dto.id] = PinPhotoDto(
        id: dto.id,
        pinId: dto.id,
        contributorId: dto.creationUser,
        contributorUsername: previousPhoto?.contributorUsername ?? '',
        observedAt: dto.creationDate,
        isOriginal: true,
        image: dto.image ?? previousPhoto?.image,
        imageThumbnail: previousPhoto?.imageThumbnail,
        imageBlurhash: dto.imageBlurhash ?? previousPhoto?.imageBlurhash,
        caption: dto.description,
      );
      _mutations[dto.id] = ++_revision;
      affected.add(dto.id);
    }
    for (final id in affected) {
      publish(id, history(id));
    }
    _notify(
      pinIds: affected,
      scopes: _scopesMatching([
        ...previousPhotos,
        for (final id in affected) ...history(id),
      ]),
    );
    await _persist({for (final id in affected) id: history(id)});
  }

  /// Capture before a remote upload so a later access change can fence its
  /// response. A new authorized upload after rejoining captures a new revision.
  int beginWrite() => _revision;

  void restoreGroupAccess(String groupId, {required int startedAt}) {
    if (!_closed && (_removedGroups[groupId] ?? 0) <= startedAt) {
      _restoredGroups[groupId] = ++_revision;
    }
  }

  bool groupAccessRestoredSince(String groupId, int startedAt) =>
      (_restoredGroups[groupId] ?? 0) > startedAt &&
      (_restoredGroups[groupId] ?? 0) > (_removedGroups[groupId] ?? 0);

  bool canWrite(PinEntity pin, int startedAt) =>
      !_closed &&
      (_removedGroups[pin.groupId] ?? 0) <= startedAt &&
      (_deletedPins[pin.pinId] ?? 0) <= startedAt;

  Future<bool> accept(
    PinEntity pin,
    PinPhotoDto photo, {
    int startedAt = 0,
  }) async {
    if (!canWrite(pin, startedAt)) return false;
    await hydrate();
    if (!canWrite(pin, startedAt)) return false;
    final previous = history(pin.pinId);
    _mutations[photo.id] = ++_revision;
    _pins[pin.pinId] = pin;
    _photos[photo.id] = photo;
    _metadataUpdates[pin.pinId] = _revision;
    _historyErrors.remove(pin.pinId);
    for (final scope in _galleries.keys) {
      if (scope.contains(pin, photo)) _galleries[scope]!.add(photo.id);
    }
    publish(pin.pinId, history(pin.pinId));
    _notify(pinIds: [pin.pinId], scopes: _scopesMatching([...previous, photo]));
    await pins.put(pin);
    await _persist({pin.pinId: history(pin.pinId)});
    return canWrite(pin, startedAt);
  }

  Future<void> removeGroup(String groupId) async {
    if (_closed) return;
    // Fence pages that began before the membership change, including records
    // for pins that were not yet present in this session's cache.
    _removedGroups[groupId] = ++_revision;
    final savedPins = await pins.getAll();
    if (_closed) return;
    _removedGroups[groupId] = ++_revision;
    _failedScopes.removeWhere((scope) => scope.groupId == groupId);
    await removePins({
      for (final pin in [..._pins.values, ...savedPins])
        if (pin.groupId == groupId) pin.pinId,
    });
  }

  Future<void> removePins(Iterable<String> ids) async {
    if (_closed) return;
    final set = ids.toSet();
    final removed = _photos.values
        .where((photo) => set.contains(photo.pinId))
        .toList();
    final affectedScopes = _scopesMatching(removed);
    _revision++;
    _photos.removeWhere((_, p) => set.contains(p.pinId));
    for (final id in set) {
      _pins.remove(id);
      _deletedPins[id] = _revision;
      _historyErrors.remove(id);
    }
    final removedPhotoIds = removed.map((photo) => photo.id).toSet();
    for (final ids in _galleries.values) {
      ids.removeAll(removedPhotoIds);
    }
    revokePinUrls?.call(set);
    _notify(pinIds: set, scopes: affectedScopes);
    await _persist({for (final id in set) id: []});
  }

  Future<PinPhotoDto?> renew(String photoId) {
    if (_closed) return Future.value();
    final pinId = _photos[photoId]?.pinId;
    final historyRequest = _historyRequests[pinId];
    if (historyRequest != null) {
      return historyRequest.then(
        (photos) => photos.where((p) => p.id == photoId).firstOrNull,
      );
    }
    final existing = _urlRequests[photoId];
    if (existing != null) return existing.future;
    final pending = _urlRequests.putIfAbsent(
      photoId,
      Completer<PinPhotoDto?>.new,
    );
    if (!_urlScheduled) {
      _urlScheduled = true;
      scheduleMicrotask(_flushUrls);
    }
    return pending.future;
  }

  Future<void> _flushUrls() async {
    _urlScheduled = false;
    final started = _revision;
    final requests = Map.fromEntries(
      _urlRequests.entries.where((e) => !_urlsInFlight.contains(e.key)),
    );
    _urlsInFlight.addAll(requests.keys);
    final ids = requests.keys.toList();
    for (var start = 0; start < ids.length; start += 100) {
      final batch = ids.skip(start).take(100).toList();
      try {
        final results = await resolvePhotos(batch);
        if (_closed) {
          for (final id in batch) {
            if (!requests[id]!.isCompleted) requests[id]!.complete();
          }
          return;
        }
        final affected = <String>{};
        final changedPhotos = <PinPhotoDto>[];
        for (final id in batch) {
          if (!results.containsKey(id)) {
            requests[id]!.completeError(
              StateError('Photo resolution unavailable'),
            );
            _urlRequests.remove(id);
            _urlsInFlight.remove(id);
            continue;
          }
          final photo = results[id];
          final old = _photos[id];
          if (old != null) {
            affected.add(old.pinId);
            changedPhotos.add(old);
          }
          if ((_mutations[id] ?? 0) > started ||
              (photo != null && (_deletedPins[photo.pinId] ?? 0) > started)) {
            requests[id]!.complete(_photos[id]);
            _urlRequests.remove(id);
            _urlsInFlight.remove(id);
            continue;
          }
          _mutations[id] = ++_revision;
          if (photo == null) {
            _photos.remove(id);
          } else {
            _photos[id] = photo;
            affected.add(photo.pinId);
            changedPhotos.add(photo);
          }
          requests[id]!.complete(photo);
          _urlRequests.remove(id);
          _urlsInFlight.remove(id);
        }
        for (final id in affected) {
          publish(id, history(id));
        }
        _notify(pinIds: affected, scopes: _scopesMatching(changedPhotos));
        await _persist({for (final id in affected) id: history(id)});
      } catch (e, s) {
        for (final id in batch) {
          if (!requests[id]!.isCompleted) requests[id]!.completeError(e, s);
          _urlRequests.remove(id);
          _urlsInFlight.remove(id);
        }
      }
    }
  }

  Future<void> refreshActive() async {
    await Future.wait({..._scopes, ..._failedScopes}.map(refreshGallery));
    for (final id in _activeHistories.toList()) {
      try {
        await refreshHistory(id);
      } catch (_) {}
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _photos.clear();
    _pins.clear();
    _galleries.clear();
    _scopes.clear();
    _failedScopes.clear();
    _galleryWatchers.clear();
    _activeHistories.clear();
    _historyWatchers.clear();
    for (final events in [..._pinEvents.values, ..._scopeEvents.values]) {
      unawaited(events.close());
    }
    for (final c in _urlRequests.values) {
      if (!c.isCompleted) c.complete();
    }
    unawaited(_changes.close());
  }
}

/// Typed additive adapter over the existing authenticated generated client.
/// The OpenAPI contract remains authoritative; no generated Dart is modified.
class PhotoApi {
  PhotoApi(this.client);
  final ApiClient client;
  Future<Map<String, Object?>> _request(
    String path,
    String method, {
    List<QueryParam> query = const [],
    Object? body,
  }) async {
    final response = await client.invokeAPI(
      path,
      method,
      query,
      body,
      {},
      {},
      'application/json',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Photo request failed');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid photo response');
    }
    return decoded;
  }

  Future<GalleryPhotoPage> gallery(PhotoScope scope, String? cursor) async {
    final data = await _request(
      '/api/v2/gallery/photos',
      'GET',
      query: [
        if (scope.userId != null) QueryParam('userId', scope.userId!),
        if (scope.groupId != null) QueryParam('groupId', scope.groupId!),
        if (cursor != null) QueryParam('cursor', cursor),
        const QueryParam('limit', '100'),
      ],
    );
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('Invalid gallery photo page');
    }
    final items = <GalleryPhotoRecord>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, Object?>) {
        throw const FormatException('Invalid gallery photo record');
      }
      final rawPin = rawItem['pin'];
      final rawPhoto = rawItem['photo'];
      if (rawPin is! Map<String, Object?> ||
          rawPhoto is! Map<String, Object?>) {
        throw const FormatException('Invalid gallery photo record');
      }
      final pinDto = PinWithOptionalImageDto.fromJson(rawPin);
      final photoDto = PinPhotoDto.fromJson(rawPhoto);
      if (pinDto == null || photoDto == null) {
        throw const FormatException('Incomplete gallery photo record');
      }
      items.add(GalleryPhotoRecord(PinEntity.fromDto(pinDto, false), photoDto));
    }
    final rawCursor = data['nextCursor'];
    String? nextCursor;
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException('Invalid gallery photo cursor');
    }
    if (rawCursor is String) {
      nextCursor = rawCursor;
    }
    return GalleryPhotoPage(items: items, nextCursor: nextCursor);
  }

  Future<Map<String, PinPhotoDto?>> resolve(List<String> ids) async {
    final data = await _request(
      '/api/v2/photos/resolve',
      'POST',
      body: <String, Object?>{'photoIds': ids},
    );
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('Invalid photo resolution response');
    }
    final result = <String, PinPhotoDto?>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, Object?> ||
          rawItem['photoId'] is! String ||
          rawItem['status'] is! int) {
        throw const FormatException('Invalid photo resolution item');
      }
      final photoId = rawItem['photoId'];
      final status = rawItem['status'];
      if (photoId is! String || status is! int) {
        throw const FormatException('Invalid photo resolution item');
      }
      if (status == 404) {
        result[photoId] = null;
      } else if (status == 200) {
        final rawPhoto = rawItem['photo'];
        if (rawPhoto is! Map<String, Object?>) {
          throw const FormatException('Missing resolved photo');
        }
        final photo = PinPhotoDto.fromJson(rawPhoto);
        if (photo == null || photo.id != photoId) {
          throw const FormatException('Mismatched resolved photo');
        }
        result[photoId] = photo;
      }
    }
    return result;
  }
}

final photoApiProvider = Provider<PhotoApi>(
  (ref) => PhotoApi(ref.watch(openApiConfigProvider)),
);
final photoLibraryProvider = Provider<PhotoLibrary>((ref) {
  final library = PhotoLibrary(
    histories: ref.watch(pinPhotoHistoryRepositoryProvider),
    pins: ref.watch(pinRepositoryProvider),
    fetchPage: (scope, cursor) =>
        ref.read(photoApiProvider).gallery(scope, cursor),
    fetchHistory: (id) async {
      final result = await ref.read(pinApiProvider).getPinPhotos(id);
      if (result == null) throw StateError('Missing photo response');
      return result;
    },
    resolvePhotos: (ids) => ref.read(photoApiProvider).resolve(ids),
    publish: (id, photos) => registerOriginalPinPhotoImageUrls(ref, id, photos),
    revokePinUrls: (ids) =>
        ref.read(suppliedImageUrlRegistryProvider).invalidatePinPhotos(ids),
  );
  ref.onDispose(library.dispose);
  return library;
});
