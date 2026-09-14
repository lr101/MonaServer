import 'dart:async';

import 'package:buff_lisa/core/sync/sync_coordinator.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  ref.watch(syncingServiceProvider.notifier);
  final coordinator = SyncCoordinator(
    sync: (isCurrent) => ref
        .read(syncingServiceProvider.notifier)
        .syncToBackend(isActive: isCurrent),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Owns app lifecycle observation; the provider owns the coordinator for this
/// application scope. Detaching the widget pauses work without leaking listeners.
class AppSyncLifecycle extends ConsumerStatefulWidget {
  const AppSyncLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppSyncLifecycle> createState() => _AppSyncLifecycleState();
}

class _AppSyncLifecycleState extends ConsumerState<AppSyncLifecycle> {
  late final SyncCoordinator _coordinator;
  late final AppLifecycleListener _lifecycle;
  late final ProviderSubscription<AccountSession> _session;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(syncCoordinatorProvider);
    _session = ref.listenManual(accountSessionProvider, (_, session) {
      _automatically(
        _coordinator.setSession(session.isActive ? session : null),
      );
    }, fireImmediately: true);
    _lifecycle = AppLifecycleListener(
      onResume: () => _automatically(_coordinator.resume()),
    );
  }

  void _automatically(Future<void> operation) {
    // SyncState exposes failures to UI. Do not leak background Future errors or
    // log request payloads, account identifiers or raw transport errors.
    unawaited(operation.catchError((Object _) {}));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _session.close();
    _automatically(_coordinator.setSession(null));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
