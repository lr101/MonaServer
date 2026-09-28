import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capstone badge has a visible distinction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Batch(batchId: 20))),
    );
    expect(find.byKey(const ValueKey('capstone-badge-mark')), findsOneWidget);
    expect(find.text('Seasoned explorer'), findsOneWidget);
  });

  testWidgets('earlier hard badge has no capstone mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Batch(batchId: 11))),
    );
    expect(find.byKey(const ValueKey('capstone-badge-mark')), findsNothing);
  });
}
