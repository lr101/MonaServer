import 'dart:async';

import 'package:buff_lisa/core/sync/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive sessions do not start sync', () async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      sync: (_) async {
        runs++;
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.refresh();
    await coordinator.resume();
    expect(runs, 0);
  });

  test(
    'session activation starts once and concurrent triggers share a run',
    () async {
      var runs = 0;
      final finish = Completer<void>();
      final coordinator = SyncCoordinator(
        sync: (_) {
          runs++;
          return finish.future;
        },
      );
      addTearDown(coordinator.dispose);
      final session = Object();
      final first = coordinator.setSession(session);
      final manual = coordinator.refresh();
      final resume = coordinator.resume();
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
      finish.complete();
      await Future.wait([first, manual, resume]);
      await coordinator.setSession(session);
      expect(runs, 1);
    },
  );

  test(
    'resume cooldown limits attempts while manual refresh bypasses it',
    () async {
      var now = DateTime.utc(2026);
      var runs = 0;
      final coordinator = SyncCoordinator(
        sync: (_) async {
          runs++;
        },
        now: () => now,
      );
      addTearDown(coordinator.dispose);
      await coordinator.setSession(Object());
      await coordinator.resume();
      expect(runs, 1);
      await coordinator.refresh();
      expect(runs, 2);
      now = now.add(const Duration(minutes: 1));
      await coordinator.resume();
      expect(runs, 3);
    },
  );

  test(
    'replacement sessions wait for old work and revoke its follow-up guard',
    () async {
      final finish = Completer<void>();
      final guards = <bool Function()>[];
      final coordinator = SyncCoordinator(
        sync: (guard) {
          guards.add(guard);
          return guards.length == 1 ? finish.future : Future<void>.value();
        },
      );
      addTearDown(coordinator.dispose);
      final old = coordinator.setSession(Object());
      await Future<void>.delayed(Duration.zero);
      final next = coordinator.setSession(Object());
      expect(guards.single(), isFalse);
      expect(guards, hasLength(1));
      finish.complete();
      await Future.wait([old, next]);
      expect(guards, hasLength(2));
      expect(guards.last(), isTrue);
    },
  );

  test(
    'cache reset revokes old work and forces a fresh serialized run',
    () async {
      final finish = Completer<void>();
      final guards = <bool Function()>[];
      final coordinator = SyncCoordinator(
        sync: (guard) {
          guards.add(guard);
          return guards.length == 1 ? finish.future : Future<void>.value();
        },
      );
      addTearDown(coordinator.dispose);
      final old = coordinator.setSession(Object());
      await Future<void>.delayed(Duration.zero);
      final next = coordinator.restart();
      expect(guards.single(), isFalse);
      expect(guards, hasLength(1));
      finish.complete();
      await Future.wait([old, next]);
      expect(guards, hasLength(2));
      expect(guards.last(), isTrue);
    },
  );

  test('logout cancels a queued session and prevents further work', () async {
    final finish = Completer<void>();
    var runs = 0;
    final coordinator = SyncCoordinator(
      sync: (_) {
        runs++;
        return finish.future;
      },
    );
    addTearDown(coordinator.dispose);
    final old = coordinator.setSession(Object());
    await Future<void>.delayed(Duration.zero);
    final next = coordinator.setSession(Object());
    await coordinator.setSession(null);
    finish.complete();
    await Future.wait([old, next]);
    await coordinator.refresh();
    expect(runs, 1);
  });

  test('failure is observable and a later manual request can retry', () async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      sync: (_) async {
        if (runs++ == 0) throw StateError('offline');
      },
    );
    addTearDown(coordinator.dispose);
    await expectLater(coordinator.setSession(Object()), throwsStateError);
    await coordinator.resume();
    expect(runs, 1);
    await coordinator.refresh();
    expect(runs, 2);
  });

  test(
    'disposal revokes active work and prevents queued replacements',
    () async {
      final finish = Completer<void>();
      var runs = 0;
      late bool Function() isCurrent;
      final coordinator = SyncCoordinator(
        sync: (guard) {
          runs++;
          isCurrent = guard;
          return finish.future;
        },
      );
      final old = coordinator.setSession(Object());
      await Future<void>.delayed(Duration.zero);
      final next = coordinator.setSession(Object());
      coordinator.dispose();
      expect(isCurrent(), isFalse);
      finish.complete();
      await Future.wait([old, next]);
      await coordinator.setSession(Object());
      expect(runs, 1);
    },
  );
}
