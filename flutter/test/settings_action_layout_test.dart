import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings action keeps large wrapped text inside its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: SettingsActionButton(
                  label: 'Permanently delete my account',
                  icon: Icons.check,
                  onPressed: () async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final button = tester.getRect(find.byType(FilledButton));
    final label = tester.getRect(find.text('Permanently delete my account'));
    expect(label.top, greaterThanOrEqualTo(button.top));
    expect(label.bottom, lessThanOrEqualTo(button.bottom));
    expect(tester.takeException(), isNull);
  });
}
