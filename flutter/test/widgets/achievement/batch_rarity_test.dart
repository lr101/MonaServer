import 'package:buff_lisa/util/types/achievement.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active personal badge names use one word', () {
    const activeIds = [
      0,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
    ];

    for (final id in activeIds) {
      final name = Achievement.getById(id).name;
      expect(
        name.trim().split(RegExp(r'\s+')),
        hasLength(1),
        reason: 'badge $id: $name',
      );
    }
  });

  testWidgets('capstone badge has a visible distinction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Batch(batchId: 20))),
    );
    expect(find.byKey(const ValueKey('capstone-badge-mark')), findsOneWidget);
    expect(find.text('Voyager'), findsOneWidget);
  });

  testWidgets('earlier hard badge has no capstone mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Batch(batchId: 11))),
    );
    expect(find.byKey(const ValueKey('capstone-badge-mark')), findsNothing);
  });

  testWidgets('photo update and gone pin badges have legendary capstones', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [Batch(batchId: 26), Batch(batchId: 29)]),
        ),
      ),
    );

    expect(find.text('Archivist'), findsOneWidget);
    expect(find.text('Steward'), findsOneWidget);
    expect(find.byKey(const ValueKey('capstone-badge-mark')), findsNWidgets(2));
  });
}
