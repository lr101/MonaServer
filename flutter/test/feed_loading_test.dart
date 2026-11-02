import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  testWidgets('feed shows pin placeholders while its first page loads', (
    tester,
  ) async {
    final result = Completer<List<PinEntity>?>();
    final pins = FutureProvider<List<PinEntity>?>((ref) => result.future);
    final controller = PagingController<int, PinEntity>(firstPageKey: 0);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                CustomFeed(pinProvider: pins, pagingController: controller),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading pins'), findsOneWidget);
    result.complete([]);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading pins'), findsNothing);
    expect(controller.itemList, isEmpty);
  });
  testWidgets('initial provider failure ends loading and shows an error', (
    tester,
  ) async {
    final result = Completer<List<PinEntity>?>();
    final pins = FutureProvider<List<PinEntity>?>(
      (ref) => result.future,
      retry: (_, _) => null,
    );
    final controller = PagingController<int, PinEntity>(firstPageKey: 0);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                CustomFeed(pinProvider: pins, pagingController: controller),
              ],
            ),
          ),
        ),
      ),
    );
    result.completeError(StateError('feed unavailable'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading pins'), findsNothing);
    expect(controller.error, isA<StateError>());
  });
}
