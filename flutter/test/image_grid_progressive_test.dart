import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pin_image_test_cache.dart';

void main() {
  late PinImageTestCache cache;
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    cache = PinImageTestCache()..install();
  });
  tearDown(() => cache.dispose());

  testWidgets('cold gallery failure offers an explicit retry without remount', (
    tester,
  ) async {
    final controller = StreamController<List<PinEntity>>.broadcast();
    final provider = StreamProvider<List<PinEntity>>(
      (ref) => controller.stream,
    );
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ImageGrid(
              pinProvider: provider,
              onRefresh: () async {
                controller.add([]);
              },
            ),
          ),
        ),
      ),
    );
    controller.addError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Unable to load images'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No images found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    unawaited(controller.close());
  });

  List<PinEntity> entries(int count) => [
    for (var index = 0; index < count; index++)
      PinEntity(
        pinId: 'pin-$index',
        photoId: 'photo-$index',
        photoThumbnailUrl: 'https://test/thumb-$index',
        photoUrl: 'https://test/full-$index',
        latitude: 0,
        longitude: 0,
        creator: 'viewer',
        groupId: 'group',
        creationDate: DateTime(2026),
        ttl: DateTime(2026),
        onlySession: false,
      ),
  ];

  Future<void> mount(
    WidgetTester tester,
    List<PinEntity> pins, {
    bool reducedMotion = false,
    bool dataReady = true,
    Object? dataError,
  }) async {
    final provider = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => dataError != null
          ? AsyncError(dataError, StackTrace.current)
          : dataReady
          ? AsyncData(pins)
          : const AsyncLoading(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: ImageGrid(pinProvider: provider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> frames(WidgetTester tester, {int count = 25}) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'shows a spinner until the first profile metadata snapshot arrives',
    (tester) async {
      await mount(tester, entries(3), dataReady: false);
      await frames(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(cache.urls, isEmpty);
      await mount(tester, entries(3));
      await frames(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(RawImage), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );

  testWidgets('keeps the grid usable while a slow visible thumbnail loads', (
    tester,
  ) async {
    final slow = Completer<void>();
    cache.gates['https://test/thumb-11'] = slow;
    await mount(tester, entries(12));
    await frames(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SquareImage).hitTestable(), findsWidgets);
    expect(cache.urls, contains('https://test/thumb-11'));
    slow.complete();
    await frames(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RawImage), findsWidgets);
    expect(cache.urls.where((url) => url.contains('/full-')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('loads more thumbnails as the user scrolls into nearby rows', (
    tester,
  ) async {
    final maximum = PaintingBinding.instance.imageCache.maximumSize;
    PaintingBinding.instance.imageCache.maximumSize = 2;
    addTearDown(
      () => PaintingBinding.instance.imageCache.maximumSize = maximum,
    );
    await mount(tester, entries(30));
    await frames(tester, count: 50);
    await tester.pump(const Duration(seconds: 1));
    final firstViewRequests = cache.urls.toSet().length;
    expect(firstViewRequests, greaterThan(0));
    expect(firstViewRequests, lessThan(30));
    final requests = cache.urls.length;
    await tester.drag(find.byType(GridView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await frames(tester);
    expect(cache.urls.length, greaterThan(requests));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets(
    'a metadata refresh keeps the existing grid visible and preserves its scroll position',
    (tester) async {
      await mount(tester, entries(30));
      await frames(tester, count: 50);
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(GridView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      final gate = Completer<void>();
      cache.gates['https://test/thumb-30'] = gate;
      await mount(tester, entries(31));
      await frames(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SquareImage).hitTestable(), findsWidgets);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        before,
      );
      gate.complete();
      await frames(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        before,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );

  testWidgets(
    'a failed metadata refresh retains the previous grid and allows recovery',
    (tester) async {
      await mount(tester, entries(3));
      await frames(tester);
      await tester.pump(const Duration(seconds: 1));
      await mount(tester, entries(3), dataReady: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await mount(tester, entries(3), dataError: StateError('Offline'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Unable to load images'), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await mount(tester, entries(3));
      await frames(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(RawImage), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );

  testWidgets(
    'leaving during a thumbnail load safely ignores the late download',
    (tester) async {
      final gate = Completer<void>();
      cache.gates['https://test/thumb-0'] = gate;
      await mount(tester, entries(3));
      await frames(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await frames(tester);
      await tester.pump(const Duration(seconds: 11));
      expect(tester.takeException(), isNull);
      expect(find.byType(GridView), findsNothing);
    },
  );

  testWidgets(
    'an unavailable thumbnail finishes loading and leaves its tile tappable',
    (tester) async {
      cache.statuses['https://test/thumb-0'] = 404;
      cache.statuses['https://test/full-0'] = 404;
      await mount(tester, entries(3), reducedMotion: true);
      await frames(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
      expect(find.byType(SquareImage).hitTestable(), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );
}
