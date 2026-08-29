import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/auth/presentation/logout_screen.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('logout returns home and reports a local cleanup failure', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/logout',
      routes: [
        GoRoute(
          path: '/logout',
          name: 'logout',
          builder: (_, _) => const LogoutScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        accountDataCleanupProvider.overrideWithValue(
          AccountDataCleanup(
            cacheCleaners: () => [
              () async => throw StateError('tile cache failed'),
            ],
            sessionDataCleaner: () async {},
          ),
        ),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'user-1',
            refreshToken: 'secret-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    tester.takeException();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(container.read(globalDataServiceProvider).userId, 'user-1');
    expect(find.textContaining('Logout incomplete'), findsOneWidget);
  });
}
