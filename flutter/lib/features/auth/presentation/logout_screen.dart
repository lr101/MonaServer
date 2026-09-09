import 'package:buff_lisa/data/service/account_cleanup_service.dart';
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

  bool _failed = false;

  Future<void> _logout() async {
    setState(() => _failed = false);
    try {
      if (widget.isCacheOnly) {
        await ref.read(accountCleanupProvider).clearCaches();
        if (!mounted) return;
        ref.invalidate(lastSeenProvider);
        ref.read(syncingServiceProvider.notifier).toInit();
        await ref.read(syncingServiceProvider.notifier).syncToBackend();
      } else {
        await ref.read(globalDataServiceProvider.notifier).logout();
      }
      if (!mounted) return;
      context.goNamed(widget.isCacheOnly ? "home" : "login");
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_failed)
              FilledButton(
                onPressed: _logout,
                child: const Text('Retry cleanup'),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 15),
            Text(
              _failed
                  ? 'Some local data could not be erased. Please retry.'
                  : widget.isCacheOnly
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
