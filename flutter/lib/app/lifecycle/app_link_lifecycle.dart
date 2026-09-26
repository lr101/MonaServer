import 'dart:async';

import 'package:buff_lisa/app/app_links.dart';
import 'package:buff_lisa/app/routing/app_router.dart';
import 'package:buff_lisa/features/email_login/data/email_login_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Routes links delivered while the app process is alive. Cold-start links are
/// captured before bootstrap and supplied to the router's initial location.
class AppLinkLifecycle extends ConsumerStatefulWidget {
  const AppLinkLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLinkLifecycle> createState() => _AppLinkLifecycleState();
}

class _AppLinkLifecycleState extends ConsumerState<AppLinkLifecycle> {
  late final StreamSubscription<Uri> _subscription;
  var _emailLinkSequence = 0;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(appLinkEventsProvider)
        .listen(_handleLink, onError: (Object _) {});
  }

  void _handleLink(Uri uri) {
    final launch = AppLaunchData.fromUri(uri);
    final emailLink = launch.emailLink;
    if (emailLink != null) {
      ref.read(runtimeEmailLinkLaunchDataProvider.notifier).state = emailLink;
      // Change the location when another login link arrives on the callback
      // screen so GoRouter creates a fresh confirmation screen for that link.
      ref
          .read(routerProvider)
          .go('/email-login/callback?launch=${++_emailLinkSequence}');
      return;
    }

    final inviteLocation = launch.groupInviteLocation;
    if (inviteLocation != null) {
      ref.read(pendingAppDestinationProvider.notifier).state = inviteLocation;
      ref.read(routerProvider).go(inviteLocation);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
