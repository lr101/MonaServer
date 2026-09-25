import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Starts Google's native update flow when Play has a newer release available.
///
/// Play only reports updates for installs that it can recognize (for example,
/// an app installed from Google Play). Local and sideloaded builds simply
/// continue without an update prompt.
class PlayStoreUpdateGuard extends StatefulWidget {
  const PlayStoreUpdateGuard({required this.child, super.key});

  final Widget child;

  @override
  State<PlayStoreUpdateGuard> createState() => _PlayStoreUpdateGuardState();
}

class _PlayStoreUpdateGuardState extends State<PlayStoreUpdateGuard> {
  StreamSubscription<InstallStatus>? _installSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final updateAvailable =
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
      final updateInProgress =
          updateInfo.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress;
      if (updateInfo.installStatus == InstallStatus.downloaded) {
        await _completeFlexibleUpdate();
      } else if ((updateAvailable || updateInProgress) &&
          updateInfo.immediateUpdateAllowed) {
        // This also resumes an immediate update after Android recreates the
        // app process while the Play flow is in progress.
        await InAppUpdate.performImmediateUpdate();
      } else if ((updateAvailable || updateInProgress) &&
          updateInfo.flexibleUpdateAllowed) {
        await _startFlexibleUpdate();
      } else if (updateAvailable || updateInProgress) {
        await _openPlayStore();
      }
    } catch (_) {
      // Play may be unavailable for local, sideloaded, or offline installs.
      // An update check must never prevent the app from starting.
    }
  }

  Future<void> _startFlexibleUpdate() async {
    _installSubscription = InAppUpdate.installUpdateListener.listen((status) {
      if (status == InstallStatus.downloaded) {
        unawaited(_completeFlexibleUpdate());
      }
    }, onError: (_) => _openPlayStore());
    await InAppUpdate.startFlexibleUpdate();
  }

  Future<void> _openPlayStore() async {
    await launchUrl(
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.TheGermanApps.buff_lisa',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {
      await _openPlayStore();
    }
  }

  @override
  void dispose() {
    _installSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
