import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/member_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/account_data_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:buff_lisa/data/service/account_data_session.dart';

typedef AccountDataCleaner = Future<void> Function();
typedef AccountDataCleanerResolver = List<AccountDataCleaner> Function();

class AccountDataCleanup {
  const AccountDataCleanup({
    required this.cacheCleaners,
    required this.sessionDataCleaner,
    this.sessionGuard,
  });

  final AccountDataCleanerResolver cacheCleaners;
  final AccountDataCleaner sessionDataCleaner;
  final AccountDataSessionGuard? sessionGuard;

  Future<void> clearCache({bool resumeSession = true}) async {
    final guard = sessionGuard;
    if (guard == null) {
      await Future.wait(cacheCleaners().map((cleaner) => cleaner()));
      return;
    }

    guard.beginCleanup(endSession: !resumeSession);
    try {
      await guard.synchronize(
        () => Future.wait(cacheCleaners().map((cleaner) => cleaner())),
      );
    } finally {
      guard.completeCleanup(resumeSession: resumeSession);
    }
  }

  Future<void> clearForLogout({
    bool continueWithSessionOnCacheFailure = false,
  }) async {
    Object? cacheError;
    StackTrace? cacheStackTrace;
    try {
      await clearCache(resumeSession: false);
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
