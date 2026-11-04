import 'dart:async';

import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/feed/presentation/active_group_feed.dart';
import 'package:buff_lisa/features/group_user_list/presentation/user_groups.dart';
import 'package:buff_lisa/features/map_home/presentation/map_home.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/features/navigation/presentation/adaptive_navigation.dart';
import 'package:buff_lisa/features/navigation/presentation/navigation_pages.dart';
import 'package:buff_lisa/features/profile/presentation/user_profile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

class Navigation extends ConsumerStatefulWidget {
  const Navigation({super.key});

  @override
  ConsumerState<Navigation> createState() => _NavigationState();
}

class _NavigationState extends ConsumerState<Navigation> {
  StreamSubscription<RemoteMessage>? _messages;

  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _messages = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.d('Got a message whilst in the foreground!');
      _logger.d('Message data: ${message.data}');

      if (message.notification != null) {
        _logger.d(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigationStateProvider);

    return AdaptiveNavigation(
      selectedIndex: state,
      onDestinationSelected: onItemTapped,
      child: NavigationPages(
        selectedIndex: state,
        children: [
          const UserGroups(),
          Camera(isActive: state == 1),
          const MapHome(),
          const ActiveGroupFeed(),
          const UserProfile(),
        ],
      ),
    );
  }

  void onItemTapped(int index) {
    ref.read(navigationStateProvider.notifier).setIndex(index);
  }
}
