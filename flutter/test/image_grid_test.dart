import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requests only the visible grid and two nearby rows', (
    tester,
  ) async {
    final requested = <String>{};
    final pins = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => AsyncData(_pins()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourceProvider.overrideWith((ref, request) {
            requested.add(request.pinId);
            return Completer<PinImageSource?>().future;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: ImageGrid(pinProvider: pins),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested.length, inInclusiveRange(9, 18));
    expect(requested, contains('pin-0'));
    expect(requested, isNot(contains('pin-50')));
    await tester.drag(find.byType(GridView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(requested, contains('pin-24'));
    expect(requested, isNot(contains('pin-99')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('retains scroll position when pin metadata refreshes', (
    tester,
  ) async {
    final state = ValueNotifier<AsyncValue<List<PinEntity>?>>(
      AsyncData(_pins()),
    );
    addTearDown(state.dispose);
    final pins = StreamProvider<List<PinEntity>?>((ref) async* {
      final updates = StreamController<List<PinEntity>?>();
      void emit() => updates.add(state.value.value);
      state.addListener(emit);
      ref.onDispose(() {
        state.removeListener(emit);
        unawaited(updates.close());
      });
      yield state.value.value;
      yield* updates.stream;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourceProvider.overrideWith(
            (ref, _) => Completer<PinImageSource?>().future,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: ImageGrid(pinProvider: pins),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GridView), const Offset(0, -800));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final before = position.pixels;
    state.value = AsyncData(_pins());
    await tester.pumpAndSettle();
    expect(position.pixels, before);
    expect(find.byType(SquareImage), findsWidgets);
  });

  testWidgets('shows empty and failure states without requesting images', (
    tester,
  ) async {
    for (final state in <AsyncValue<List<PinEntity>?>>[
      const AsyncData([]),
      AsyncError(StateError('failed'), StackTrace.current),
    ]) {
      final pins = Provider<AsyncValue<List<PinEntity>?>>((ref) => state);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: ImageGrid(pinProvider: pins)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(state.hasError ? 'Unable to load images' : 'No images found'),
        findsOneWidget,
      );
      expect(find.byType(SquareImage), findsNothing);
    }
  });
}

List<PinEntity> _pins() => [
  for (var i = 0; i < 100; i++)
    PinEntity(
      pinId: 'pin-$i',
      latitude: 0,
      longitude: 0,
      creationDate: DateTime(2026),
      creator: 'viewer',
      groupId: 'group',
      ttl: DateTime(2026),
      onlySession: false,
    ),
];
