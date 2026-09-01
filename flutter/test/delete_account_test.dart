import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/delete_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeAuthService extends AuthService {
  @override
  FutureOr<bool> build() => true;

  @override
  Future<String?> getDeleteCode() async => null;

  @override
  Future<String?> deleteAccount(int code) async {
    ref.read(globalDataServiceProvider.notifier).state = const GlobalDataDto(
      userId: null,
      refreshToken: null,
      cameras: [],
    );
    return 'Your account was deleted, but local cleanup failed. Please restart the app.';
  }
}

void main() {
  testWidgets(
    'delete account navigates to login after server deletion and local cleanup failure',
    (tester) async {
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/delete-account',
        routes: [
          GoRoute(
            path: '/delete-account',
            name: 'delete-account',
            builder: (_, _) => const DeleteAccount(),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (_, _) => const Scaffold(body: Text('Login')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith(FakeAuthService.new),
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
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pump();
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/login');
    },
  );
}
