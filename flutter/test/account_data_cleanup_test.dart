import 'dart:async';

import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryAccountData {
  MemoryAccountData(this.values, {this.waitFor});

  final List<String> values;
  final Future<void>? waitFor;

  Future<void> clear() async {
    await waitFor;
    values.clear();
  }
}

void main() {
  test(
    'logout cleanup waits until every account-owned cache is empty',
    () async {
      final driftCache = MemoryAccountData(['group', 'pin']);
      final imageCache = MemoryAccountData(['profile-image']);
      final tileCache = MemoryAccountData(['tile']);
      final externalCache = MemoryAccountData(['network-image']);
      final sessionData = MemoryAccountData(['credential', 'profile']);
      final delayedExternalCache = Completer<void>();
      final delayedCache = MemoryAccountData([
        'delayed-external-image',
      ], waitFor: delayedExternalCache.future);
      final cleanup = AccountDataCleanup(
        cacheCleaners: () => [
          driftCache.clear,
          imageCache.clear,
          tileCache.clear,
          externalCache.clear,
          delayedCache.clear,
        ],
        sessionDataCleaner: sessionData.clear,
      );

      var completed = false;
      final clearing = cleanup.clearForLogout().then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      expect(driftCache.values, isEmpty);
      expect(imageCache.values, isEmpty);
      expect(tileCache.values, isEmpty);
      expect(externalCache.values, isEmpty);
      expect(delayedCache.values, ['delayed-external-image']);
      expect(sessionData.values, ['credential', 'profile']);

      delayedExternalCache.complete();
      await clearing;

      expect(delayedCache.values, isEmpty);
      expect(sessionData.values, isEmpty);
    },
  );

  test('cleanup resolves the current cache for each account session', () async {
    var currentSessionCache = MemoryAccountData(['first-session-image']);
    final cleanup = AccountDataCleanup(
      cacheCleaners: () => [currentSessionCache.clear],
      sessionDataCleaner: () async {},
    );

    await cleanup.clearCache();
    currentSessionCache = MemoryAccountData(['second-session-image']);
    await cleanup.clearCache();

    expect(currentSessionCache.values, isEmpty);
  });
}
