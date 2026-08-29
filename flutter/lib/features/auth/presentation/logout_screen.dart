import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LogoutScreen extends ConsumerStatefulWidget {
  final bool isCacheOnly;
  const LogoutScreen({super.key, this.isCacheOnly = false});

  @override
  ConsumerState<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends ConsumerState<LogoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logout();
    });
  }

  Future<void> _logout() async {
    if (widget.isCacheOnly) {
      await ref.read(accountDataCleanupProvider).clearCache();
      ref.invalidate(lastSeenProvider);
      ref.read(syncingServiceProvider.notifier).toInit();
      await ref.read(syncingServiceProvider.notifier).syncToBackend();
    } else {
      await ref.read(globalDataServiceProvider.notifier).logout();
    }

    if (!mounted) return;
    context.goNamed(widget.isCacheOnly ? "home" : "login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 15),
            Text(
              widget.isCacheOnly
                  ? "Deleting cache... Please wait."
                  : "Logging out... Please wait.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
