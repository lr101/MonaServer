import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_thumbnail_prefetch_coordinator.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets(
    'loads a bounded tile window and displays arriving network bytes',
    (tester) async {
      final requested = <String>{};
      final prefetched = <String>{};
      final updates = StreamController<Uint8List?>.broadcast();
      addTearDown(updates.close);
      final pins = Provider<AsyncValue<List<PinEntity>?>>(
        (ref) => AsyncData(_pins()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinGridImageBytesProvider.overrideWith((ref, id) {
              requested.add(id);
              return updates.stream;
            }),
            pinThumbnailPrefetchCoordinatorProvider.overrideWithValue(
              PinThumbnailPrefetchCoordinator(
                repository: _PrefetchRepository(prefetched),
              ),
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
      await tester.pump();
      await tester.pump();
      // Three visible rows plus three buffered rows; distant tiles stay unloaded.
      expect(requested, {for (var i = 0; i < 18; i++) 'pin-$i'});
      expect(
        prefetched,
        containsAll({
          'pin-9',
          'pin-10',
          'pin-11',
          'pin-12',
          'pin-13',
          'pin-14',
        }),
      );
      expect(find.byType(Image), findsNothing);
      updates.add(Uint8List.fromList(kTransparentImage));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(9));
      await tester.drag(find.byType(ImageGrid), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(requested.contains('pin-20'), isTrue);
      expect(requested.contains('pin-99'), isFalse);
    },
  );

  testWidgets(
    'batches profile thumbnail URLs and warms the next rows before a fast scroll',
    (tester) async {
      final readBatches = <List<BatchReadItem>>[];
      final warmed = <String>{};
      final registry = SuppliedImageUrlRegistry();
      addTearDown(registry.dispose);
      final coalescer = BatchReadCoalescer(
        window: Duration.zero,
        read: (items) async {
          readBatches.add(items);
          return items
              .map(
                (item) => BatchReadResult(
                  kind: batchResultKind(item.kind),
                  id: item.id,
                  status: 200,
                  imageUrl: 'https://images.example/${item.id}',
                ),
              )
              .toList();
        },
        onResult: (key, result) =>
            registry.register(key.kind, key.id, result.imageUrl, notify: false),
      );
      addTearDown(coalescer.dispose);
      final pins = Provider<AsyncValue<List<PinEntity>?>>(
        (ref) => AsyncData(_pins()),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinGridImageBytesProvider.overrideWith(
              (ref, id) => const Stream.empty(),
            ),
            batchReadCoalescerProvider.overrideWithValue(coalescer),
            suppliedImageUrlRegistryProvider.overrideWithValue(registry),
            pinThumbnailPrefetchCoordinatorProvider.overrideWithValue(
              PinThumbnailPrefetchCoordinator(
                repository: _PrefetchRepository(warmed),
              ),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      final initiallyResolved = readBatches
          .expand((batch) => batch)
          .where((item) => item.kind == BatchReadItemKindEnum.pinImageThumbnail)
          .map((item) => item.id)
          .toSet();
      expect(readBatches, hasLength(1));
      expect(readBatches.single, hasLength(30));
      expect(
        initiallyResolved,
        containsAll({'pin-0', 'pin-8', 'pin-9', 'pin-14'}),
      );
      expect(initiallyResolved, isNot(contains('pin-99')));
      expect(
        readBatches.single
            .where((item) => item.kind == BatchReadItemKindEnum.pinImage)
            .map((item) => item.id),
        containsAll({'pin-0', 'pin-8', 'pin-9', 'pin-14'}),
      );
      expect(
        warmed,
        containsAll({
          'pin-9',
          'pin-10',
          'pin-11',
          'pin-12',
          'pin-13',
          'pin-14',
        }),
      );

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(600);
      await tester.pumpAndSettle();

      expect(warmed, anyOf(contains('pin-24'), contains('pin-27')));
      final allResolved = readBatches
          .expand((batch) => batch)
          .where((item) => item.kind == BatchReadItemKindEnum.pinImageThumbnail)
          .map((item) => item.id)
          .toSet();
      expect(allResolved, contains('pin-24'));
      expect(allResolved, isNot(contains('pin-99')));
    },
  );

  testWidgets('throttles missing image URL lookups while scrolling', (
    tester,
  ) async {
    final requests = <(BatchReadItemKindEnum, String), int>{};
    final registry = SuppliedImageUrlRegistry();
    addTearDown(registry.dispose);
    final coalescer = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async {
        return items.map((item) {
          final key = (item.kind, item.id);
          requests.update(key, (count) => count + 1, ifAbsent: () => 1);
          return BatchReadResult(
            kind: batchResultKind(item.kind),
            id: item.id,
            // Cover both a successful response with no image URL and a
            // missing resource. Neither result should be re-requested on each
            // scroll notification.
            status: item.id == 'pin-1' ? 404 : 200,
          );
        }).toList();
      },
      onResult: (key, result) =>
          registry.register(key.kind, key.id, result.imageUrl, notify: false),
    );
    addTearDown(coalescer.dispose);
    final pins = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => AsyncData(_pins()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinGridImageBytesProvider.overrideWith(
            (ref, id) => const Stream.empty(),
          ),
          batchReadCoalescerProvider.overrideWithValue(coalescer),
          suppliedImageUrlRegistryProvider.overrideWithValue(registry),
          pinThumbnailPrefetchCoordinatorProvider.overrideWithValue(
            PinThumbnailPrefetchCoordinator(
              repository: _PrefetchRepository({}),
            ),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    const missingThumbnail = (BatchReadItemKindEnum.pinImageThumbnail, 'pin-0');
    const failedThumbnail = (BatchReadItemKindEnum.pinImageThumbnail, 'pin-1');
    expect(requests[missingThumbnail], 1);
    expect(requests[failedThumbnail], 1);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    for (final offset in [100.0, 0.0, 100.0, 0.0]) {
      position.jumpTo(offset);
      await tester.pumpAndSettle();
    }

    expect(requests[missingThumbnail], 1);
    expect(requests[failedThumbnail], 1);
  });

  testWidgets('keeps loaded edge tiles stable during a short scroll reversal', (
    tester,
  ) async {
    final subscriptions = <String, int>{};
    final bytes = Uint8List.fromList(kTransparentImage);
    final pins = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => AsyncData(_pins()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinGridImageBytesProvider.overrideWith((ref, id) {
            subscriptions.update(id, (count) => count + 1, ifAbsent: () => 1);
            return Stream.value(bytes);
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
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(110);
    await tester.pumpAndSettle();
    position.jumpTo(0);
    await tester.pump();
    // A loaded row briefly leaving view must not restart its async image load
    // or flash a placeholder on the reverse scroll.
    expect(subscriptions['pin-0'], 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pin-0')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('keeps scroll position when pin metadata refreshes', (
    tester,
  ) async {
    final updates = StreamController<List<PinEntity>>();
    addTearDown(updates.close);
    final pins = StreamProvider<List<PinEntity>>((ref) async* {
      yield _pins();
      yield* updates.stream;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinGridImageBytesProvider.overrideWith(
            (ref, id) => const Stream.empty(),
          ),
          pinThumbnailPrefetchCoordinatorProvider.overrideWithValue(
            PinThumbnailPrefetchCoordinator(
              repository: _PrefetchRepository({}),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: ImageGrid(pinProvider: pins)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ImageGrid), const Offset(0, -1600));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final before = position.pixels;
    expect(before, greaterThan(1000));
    updates.add(_pins());
    await tester.pumpAndSettle();
    expect(position.pixels, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps loaded tiles and scroll position during profile refresh', (
    tester,
  ) async {
    final pins =
        NotifierProvider<_ProfilePinsController, AsyncValue<List<PinEntity>?>>(
          _ProfilePinsController.new,
        );
    final container = ProviderContainer(
      overrides: [
        pinGridImageBytesProvider.overrideWith(
          (ref, id) => const Stream.empty(),
        ),
        pinThumbnailPrefetchCoordinatorProvider.overrideWithValue(
          PinThumbnailPrefetchCoordinator(repository: _PrefetchRepository({})),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: ImageGrid(pinProvider: pins)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialPosition = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(1200);
    await tester.pumpAndSettle();
    final positionBeforeRefresh = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(positionBeforeRefresh, greaterThan(initialPosition));

    container.read(pins.notifier).beginRefresh();
    await tester.pump();
    expect(find.byType(GridView), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      positionBeforeRefresh,
    );

    container.read(pins.notifier).finishRefresh();
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      positionBeforeRefresh,
    );
  });

  testWidgets('shows an error when image loading fails', (tester) async {
    final pins = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => AsyncError<List<PinEntity>?>(
        StateError('pin load failed'),
        StackTrace.current,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ImageGrid(pinProvider: pins)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load images'), findsOneWidget);
    expect(find.text('No images found'), findsNothing);
  });
}

List<PinEntity> _pins() => List.generate(
  100,
  (index) => PinEntity(
    pinId: 'pin-$index',
    latitude: 0,
    longitude: 0,
    creationDate: DateTime(2026),
    creator: 'user',
    groupId: 'group',
    ttl: DateTime(2026),
    onlySession: true,
  ),
);

class _PrefetchRepository implements IImageRepository {
  _PrefetchRepository(this.requested);
  final Set<String> requested;
  @override
  Future<Uint8List?> fetchImage(
    String id,
    bool keepAlive, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async {
    requested.add(id);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfilePinsController extends Notifier<AsyncValue<List<PinEntity>?>> {
  @override
  AsyncValue<List<PinEntity>?> build() => AsyncData(_pins());

  void beginRefresh() => state = const AsyncLoading<List<PinEntity>?>();

  void finishRefresh() => state = AsyncData(_pins());
}
