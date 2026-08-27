import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/feed/presentation/active_group_feed.dart';
import 'package:buff_lisa/features/group_user_list/presentation/user_groups.dart';
import 'package:buff_lisa/features/map_home/presentation/map_home.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
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
  late PageController _pageController;

  late final List<Widget> widgetOptions;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(navigationStateProvider));
    widgetOptions = <Widget>[
      const UserGroups(),
      const Camera(),
      const MapHome(),
      const ActiveGroupFeed(),
      const UserProfile(),
    ];
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.d('Got a message whilst in the foreground!');
      _logger.d('Message data: ${message.data}');

      if (message.notification != null) {
        _logger.d('Message also contained a notification: ${message.notification}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncingServiceProvider, (_, _) => ());
    ref.listen(navigationStateProvider, (prev, next) => _pageController.jumpToPage(next));
    final state = ref.watch(navigationStateProvider);

    return Scaffold(
      backgroundColor: state == 2 ? Colors.transparent : null,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: widgetOptions,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state,
        onDestinationSelected: onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon: Icon(Icons.add_location_alt),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void onItemTapped(int index) {
    ref.read(navigationStateProvider.notifier).setIndex(index);
  }
}
