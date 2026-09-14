import 'dart:async';

import 'package:buff_lisa/app/lifecycle/sync_lifecycle.dart';
import 'package:buff_lisa/core/sync/sync_coordinator.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'startup runs once, rebuilds do not sync, and resume obeys cooldown',
    (tester) async {
      var now = DateTime.utc(2026);
      var runs = 0;
      final coordinator = SyncCoordinator(
        sync: (_) async {
          runs++;
        },
        now: () => now,
      );
      addTearDown(coordinator.dispose);
      final container = ProviderContainer(
        overrides: [
          syncCoordinatorProvider.overrideWithValue(coordinator),
          accountSessionProvider.overrideWithValue(AccountSession(true)),
        ],
      );
      addTearDown(container.dispose);
      Widget app(String text) => UncontrolledProviderScope(
        container: container,
        child: AppSyncLifecycle(
          child: Text(text, textDirection: TextDirection.ltr),
        ),
      );
      await tester.pumpWidget(app('first'));
      await tester.pump();
      expect(runs, 1);
      await tester.pumpWidget(app('rebuilt'));
      expect(runs, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(runs, 1);
      now = now.add(const Duration(minutes: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(runs, 2);
    },
  );

  testWidgets('login starts sync and logout revokes pending work', (
    tester,
  ) async {
    var session = AccountSession(false);
    var runs = 0;
    late bool Function() isCurrent;
    final finish = Completer<void>();
    final coordinator = SyncCoordinator(
      sync: (guard) {
        runs++;
        isCurrent = guard;
        return finish.future;
      },
    );
    addTearDown(coordinator.dispose);
    final container = ProviderContainer(
      overrides: [
        syncCoordinatorProvider.overrideWithValue(coordinator),
        accountSessionProvider.overrideWith((_) => session),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppSyncLifecycle(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(runs, 0);
    session = AccountSession(true);
    container.invalidate(accountSessionProvider);
    await tester.pump();
    expect(runs, 1);
    session.revoke();
    session = AccountSession(false);
    container.invalidate(accountSessionProvider);
    await tester.pump();
    expect(isCurrent(), isFalse);
    finish.complete();
    await tester.pump();
  });

  testWidgets('unmount removes observers and session subscriptions', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    var session = AccountSession(true);
    var runs = 0;
    final coordinator = SyncCoordinator(
      sync: (_) async {
        runs++;
      },
      now: () => now,
    );
    addTearDown(coordinator.dispose);
    final container = ProviderContainer(
      overrides: [
        syncCoordinatorProvider.overrideWithValue(coordinator),
        accountSessionProvider.overrideWith((_) => session),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppSyncLifecycle(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(runs, 1);
    await tester.pumpWidget(const SizedBox());
    now = now.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    session = AccountSession(true);
    container.invalidate(accountSessionProvider);
    await tester.pump();
    await coordinator.refresh();
    expect(runs, 1);
  });

  testWidgets('automatic failures do not escape into the widget framework', (
    tester,
  ) async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      sync: (_) {
        runs++;
        return Future<void>.error(StateError('offline'));
      },
    );
    addTearDown(coordinator.dispose);
    final container = ProviderContainer(
      overrides: [
        syncCoordinatorProvider.overrideWithValue(coordinator),
        accountSessionProvider.overrideWithValue(AccountSession(true)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AppSyncLifecycle(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(runs, 1);
    expect(tester.takeException(), isNull);
  });
}
