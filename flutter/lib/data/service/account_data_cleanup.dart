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

typedef AccountDataCleaner = Future<void> Function();

class AccountDataCleanup {
  const AccountDataCleanup({
    required this.cacheCleaners,
    required this.sessionDataCleaner,
  });

  final List<AccountDataCleaner> cacheCleaners;
  final AccountDataCleaner sessionDataCleaner;

  Future<void> clearCache() async {
    await Future.wait(cacheCleaners.map((cleaner) => cleaner()));
  }

  Future<void> clearForLogout() async {
    await Future.wait([
      ...cacheCleaners.map((cleaner) => cleaner()),
      sessionDataCleaner(),
    ]);
  }
}

final accountDataCleanupProvider = Provider<AccountDataCleanup>((ref) {
  return AccountDataCleanup(
    cacheCleaners: [
      ref.read(pinImageRepositoryProvider).deleteAll,
      ref.read(groupRepositoryProvider).deleteAll,
      ref.read(groupProfileRepoProvider).deleteAll,
      ref.read(groupProfileSmallRepoProvider).deleteAll,
      ref.read(groupPinImageRepoProvider).deleteAll,
      ref.read(memberRepositoryProvider).deleteAll,
      ref.read(pinRepositoryProvider).deleteAll,
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
  );
});
