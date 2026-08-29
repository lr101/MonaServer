import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/member_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mutex/mutex.dart';

typedef AccountDataCleaner = Future<void> Function();
typedef AccountDataCleanerResolver = List<AccountDataCleaner> Function();

class AccountDataSessionGuard {
  final Mutex _mutex = Mutex();
  int _generation = 0;

  int get generation => _generation;

  void invalidate() {
    _generation++;
  }

  bool isCurrent(int generation) => generation == _generation;

  Future<T> synchronize<T>(Future<T> Function() action) {
    return _mutex.protect(action);
  }

  Future<bool> runIfCurrent(int generation, Future<void> Function() action) {
    return synchronize(() async {
      if (generation != _generation) return false;
      await action();
      return true;
    });
  }
}

class AccountDataCleanup {
  const AccountDataCleanup({
    required this.cacheCleaners,
    required this.sessionDataCleaner,
    this.sessionGuard,
  });

  final AccountDataCleanerResolver cacheCleaners;
  final AccountDataCleaner sessionDataCleaner;
  final AccountDataSessionGuard? sessionGuard;

  Future<void> clearCache() async {
    final guard = sessionGuard;
    if (guard == null) {
      await Future.wait(cacheCleaners().map((cleaner) => cleaner()));
      return;
    }

    guard.invalidate();
    await guard.synchronize(
      () => Future.wait(cacheCleaners().map((cleaner) => cleaner())),
    );
  }

  Future<void> clearForLogout({
    bool continueWithSessionOnCacheFailure = false,
  }) async {
    Object? cacheError;
    StackTrace? cacheStackTrace;
    try {
      await clearCache();
    } catch (error, stackTrace) {
      if (!continueWithSessionOnCacheFailure) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      cacheError = error;
      cacheStackTrace = stackTrace;
    }

    try {
      await sessionDataCleaner();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (cacheError != null) {
      Error.throwWithStackTrace(cacheError, cacheStackTrace!);
    }
  }
}

final accountDataCleanupProvider = Provider<AccountDataCleanup>((ref) {
  return AccountDataCleanup(
    cacheCleaners: () => [
      ref.read(pinImageRepositoryProvider).deleteAll,
      ref.read(groupRepositoryProvider).deleteAll,
      ref.read(groupProfileRepoProvider).deleteAll,
      ref.read(groupProfileSmallRepoProvider).deleteAll,
      ref.read(groupPinImageRepoProvider).deleteAll,
      ref.read(memberRepositoryProvider).deleteAll,
      ref.read(pinRepositoryProvider).deleteAll,
      ref.read(pinLikeRepositoryProvider).deleteAll,
      ref.read(userImageRepoProvider).deleteAll,
      ref.read(userImageSmallRepoProvider).deleteAll,
      ref.read(userLikeRepositoryProvider).deleteAll,
      ref.read(userRepositoryProvider).deleteAll,
      ref.read(userPinsRepositoryProvider).deleteAll,
      () async {
        if (!kIsWeb) {
          await const FMTCStore('tileStore').manage.reset();
        }
      },
      () => DefaultCacheManager().emptyCache(),
    ],
    sessionDataCleaner: ref.read(globalDataRepositoryProvider).logout,
    sessionGuard: ref.read(accountDataSessionGuardProvider),
  );
});

final accountDataSessionGuardProvider = Provider<AccountDataSessionGuard>(
  (ref) => AccountDataSessionGuard(),
);
