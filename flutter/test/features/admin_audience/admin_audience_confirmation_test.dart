import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_audience/presentation/admin_audience_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmation is disabled for an empty selected audience', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAudienceConfirmation(
            selection: AdminAudienceSelection.selected(const <String>{}),
            onConfirm: () => confirmed = true,
          ),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('admin-audience-confirm')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('admin-audience-confirm')));
    expect(confirmed, isFalse);
    expect(find.text('Select at least one account.'), findsOneWidget);
  });

  testWidgets('confirmation shows frozen preview counts and confirms', (
    tester,
  ) async {
    var confirmed = false;
    final preview = AdminAudiencePreview(
      snapshotId: 'snapshot-1',
      accountAudienceCount: 4,
      eligibleRecipientCount: 3,
      excludedCount: 1,
      deviceDeliveryCount: 5,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAudienceConfirmation(
            selection: AdminAudienceSelection.selected(const {
              'user-1',
              'user-2',
            }),
            preview: preview,
            onConfirm: () => confirmed = true,
          ),
        ),
      ),
    );

    expect(find.text('4 accounts in this snapshot'), findsOneWidget);
    expect(find.text('3 eligible recipients'), findsOneWidget);
    expect(find.text('1 excluded'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-audience-confirm')));
    expect(confirmed, isTrue);
  });
}
