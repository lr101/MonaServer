import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pending_pin_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

final pendingPinUploaderProvider = Provider<PendingPinUploader>((ref) {
  return PendingPinUploader(ref);
});

/// Shared by Android and Web. The same durable row and key are used for every
/// retry, including after an app restart or a lost server response.
class PendingPinUploader {
  PendingPinUploader(this.ref);

  final Ref ref;
  final Map<String, Future<String?>> _active = {};
  final Set<String> _discarding = {};

  Future<void> uploadAll({bool Function()? isActive}) async {
    final owner = ref.read(userIdProvider);
    final pending = ref.read(pendingPinRepositoryProvider);
    Object? firstError;
    StackTrace? firstStack;
    for (final row in await pending.forOwner(owner)) {
      if (isActive?.call() == false) return;
      try {
        await upload(row.pinId, isActive: isActive);
      } on ApiException catch (error) {
        if (error.code != 409) {
          firstError ??= error;
          firstStack ??= StackTrace.current;
        }
        // Keep rejected drafts and continue delivering independent posts.
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStack ??= stackTrace;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  Future<String?> upload(String pinId, {bool Function()? isActive}) {
    if (_discarding.contains(pinId)) return Future<String?>.value();
    return _active.putIfAbsent(pinId, () {
      final future = _upload(pinId, isActive: isActive);
      unawaited(
        future
            .whenComplete(() => _active.remove(pinId))
            .catchError((Object _) => null),
      );
      return future;
    });
  }

  Future<String?> discard(String pinId) async {
    _discarding.add(pinId);
    try {
      String? completedPinID;
      final pending = ref.read(pendingPinRepositoryProvider);
      final active = _active[pinId];
      await pending.requestCancel(pinId);
      if (active == null) {
        final row = await pending.get(pinId);
        if (row?.attempted == false) await pending.remove(pinId);
      } else {
        try {
          completedPinID = await active;
        } catch (_) {
          // Keep the cancellation row: the request may have reached the server.
        }
      }
      return completedPinID;
    } finally {
      _discarding.remove(pinId);
    }
  }

  Future<String?> _upload(String pinId, {bool Function()? isActive}) async {
    final session = captureSession(ref);
    final owner = session.userId;
    bool isCurrent() =>
        isCurrentSession(ref, session) && (isActive?.call() ?? true);
    if (owner == null || !isCurrent()) return null;
    final pending = ref.read(pendingPinRepositoryProvider);
    final rows = await pending.forOwner(owner);
    final matches = rows.where((row) => row.pinId == pinId);
    if (matches.isEmpty || !isCurrent()) return null;
    final row = matches.single;
    final pins = ref.read(pinRepositoryProvider);
    final images = ref.read(pinImageRepositoryProvider);
    final draft = PinEntity(
      pinId: row.pinId,
      latitude: row.latitude,
      longitude: row.longitude,
      creationDate: row.creationDate,
      title: row.title,
      description: row.description,
      creator: row.ownerId,
      groupId: row.groupId,
      keepAlive: true,
      onlySession: false,
      ttl: DateTime.now(),
    );
    // Keep the local cache warm without making cache latency hold up the POST.
    // A successful response waits for this projection before replacing the
    // draft with the server entity. On failure, the durable outbox is enough to
    // restore it again on the next attempt.
    final cacheRestore = row.cancelRequested
        ? Future<void>.value()
        : _restoreCachedDraft(row, draft, pins, images, pending, isCurrent);
    try {
      await pending.markAttempted(row.pinId);
      if (!isCurrent()) return null;
      PinWithOptionalImageDto? result;
      try {
        result = await ref
            .read(pinApiProvider)
            .createPin(
              draft.toRequestDto(row.image),
              idempotencyKey: row.pinId,
            );
      } on ApiException catch (error) {
        final latest = await pending.get(row.pinId);
        if (error.code == 409 && latest?.cancelRequested == true) {
          await cacheRestore;
          await _removeCancelledDraft(pending, row.pinId, pins, images);
        }
        rethrow;
      }
      if (!isCurrent()) return null;
      if (result == null) throw StateError('Pin create returned no pin');
      await cacheRestore;
      if (!isCurrent()) return null;
      final latest = await pending.get(row.pinId);
      if (!isCurrent()) return null;
      if (latest?.cancelRequested == true) {
        await ref.read(pinApiProvider).deletePin(result.id);
        await _removeCancelledDraft(pending, row.pinId, pins, images);
        return null;
      }
      if (latest == null) return null;
      final synced = PinEntity.fromDto(result, false, keepAlive: true);
      await pins.replacePin(row.pinId, synced);
      if (!isCurrent()) return null;
      await images.addImage(synced.pinId, row.image, true);
      if (synced.pinId != row.pinId) await images.delete(row.pinId);
      if (!isCurrent()) return null;
      await pending.remove(row.pinId);
      ref.invalidate(userXpProvider(owner));
      ref.invalidate(groupProgressionProvider(row.groupId));
      ref.invalidate(groupAchievementsProvider(row.groupId));
      return synced.pinId;
    } on ApiException catch (error) {
      if (isCurrent()) {
        await pending.recordError(row.pinId, 'HTTP ${error.code}');
      }
      rethrow;
    }
  }

  Future<void> _restoreCachedDraft(
    PendingPinCreateDb row,
    PinEntity draft,
    IPinRepository pins,
    IImageRepository images,
    PendingPinRepository pending,
    bool Function() isCurrent,
  ) async {
    try {
      if (!isCurrent()) return;
      if (await pins.get(row.pinId) == null) {
        final latest = await pending.get(row.pinId);
        if (!isCurrent() || latest == null || latest.cancelRequested) return;
        await pins.put(draft);
      }
      if (!isCurrent()) return;
      final latest = await pending.get(row.pinId);
      if (latest == null || latest.cancelRequested) return;
      await images.addImage(row.pinId, row.image, true);
    } catch (_) {
      // Cache writes are best effort; durable outbox bytes remain available.
    }
  }

  Future<void> _removeCancelledDraft(
    PendingPinRepository pending,
    String pinId,
    IPinRepository pins,
    IImageRepository images,
  ) async {
    // Clear the cached draft while the tombstone still prevents startup from
    // migrating it back into the outbox. If either delete fails, a retry can
    // finish cleanup before the tombstone is removed.
    await pins.delete(pinId);
    await images.delete(pinId);
    await pending.remove(pinId);
  }
}
