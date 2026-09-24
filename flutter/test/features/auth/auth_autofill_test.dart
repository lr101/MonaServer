import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/auth/presentation/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(
    () => dotenv.loadFromString(envString: 'API_HOST=https://example.test'),
  );

  testWidgets('password login fields expose autofill hints in one group', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(userId: null, refreshToken: null, cameras: []),
          ),
        ],
        child: const MaterialApp(home: Auth()),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-toggle-signin-method')));
    await tester.pumpAndSettle();

    final username = tester.widget<TextField>(
      find.byKey(const Key('auth-identifier')),
    );
    final password = tester.widget<TextField>(
      find.byKey(const Key('auth-password')),
    );

    expect(username.autofillHints, [AutofillHints.username]);
    expect(password.autofillHints, [AutofillHints.password]);
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('auth-identifier')),
        matching: find.byType(AutofillGroup),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('auth-password')),
        matching: find.byType(AutofillGroup),
      ),
      findsOneWidget,
    );

    final group = tester.widget<AutofillGroup>(find.byType(AutofillGroup));
    expect(group.onDisposeAction, AutofillContextAction.cancel);
  });
}
