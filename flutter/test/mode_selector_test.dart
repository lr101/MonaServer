import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('map scope shows labels and lets users change scope', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ModeSelector())),
        ),
      ),
    );
    expect(find.byTooltip('Groups'), findsOneWidget);
    expect(find.byTooltip('Personal'), findsOneWidget);
    await tester.tap(find.byTooltip('Personal'));
    await tester.pumpAndSettle();
    expect(preferences.getString('viewState'), 'personal');
  });
  testWidgets('scope options fit a narrow phone with larger text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: MapScopeControls(groupHint: Text('Join a Group')),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
