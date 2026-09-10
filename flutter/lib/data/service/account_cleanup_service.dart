import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Platform caches are separate from the account's Drift rows.
final clearPlatformCachesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await Future.wait([
      DefaultCacheManager().emptyCache(),
      if (!kIsWeb) const FMTCStore('tileStore').manage.reset(),
    ]);
  };
});

final accountCleanupProvider = Provider<AccountCleanup>((ref) {
  return AccountCleanup(
    ref.watch(driftRepoProvider),
    ref.watch(clearPlatformCachesProvider),
    onCachesCleared: () => ref.invalidate(accountDatabaseProvider),
  );
});

class AccountCleanup {
  AccountCleanup(
    this.database,
    this.clearPlatformCaches, {
    this.onCachesCleared,
  });

  final void Function()? onCachesCleared;

  final AppDatabase database;
  final Future<void> Function() clearPlatformCaches;

  Future<void> clearCaches() async {
    // Include every table, including pin likes and retained offline pictures.
    // A single transaction also waits for already-started local transactions.
    try {
      await Future.wait([
        database.transaction(() async {
          for (final table in database.allTables) {
            await database.delete(table).go();
          }
        }),
        clearPlatformCaches(),
      ]);
    } finally {
      onCachesCleared?.call();
    }
  }
}
