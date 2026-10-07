import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_thumbnail_prefetch_coordinator.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image repositories share one limit for object downloads', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [accountDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final started = Completer<void>();
    final release = Completer<void>();
    var active = 0;
    var maximumActive = 0;

    await http.runWithClient(
      () async {
        final thumbnails = container.read(pinThumbnailRepositoryProvider);
        final originals = container.read(pinImageRepositoryProvider);
        final requests = <Future<Object?>>[
          for (var index = 0; index < 4; index++)
            thumbnails.fetchImageFromUrl(
              'thumbnail-$index',
              'https://images.example/thumbnail-$index',
              false,
            ),
          for (var index = 0; index < 4; index++)
            originals.fetchImageFromUrl(
              'original-$index',
              'https://images.example/original-$index',
              false,
            ),
          originals.overrideUrl(
            'replacement',
            'https://images.example/replacement',
            false,
          ),
        ];
        await started.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final beforeRelease = maximumActive;
        release.complete();
        await Future.wait(requests);

        expect(beforeRelease, lessThanOrEqualTo(6));
        expect(maximumActive, lessThanOrEqualTo(6));
      },
      () => MockClient((_) async {
        active++;
        if (active > maximumActive) maximumActive = active;
        if (maximumActive >= 6 && !started.isCompleted) started.complete();
        await release.future;
        active--;
        return http.Response.bytes([1], 200);
      }),
    );
  });

  test('a visible thumbnail starts before queued look-ahead images', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final started = <String>[];
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      maxConcurrentDownloads: 1,
      getImageUrl: (id) async => 'https://images.example/$id',
      httpGet: (uri) async {
        started.add(uri.pathSegments.single);
        if (uri.pathSegments.single == 'ahead-1') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return http.Response.bytes([1], 200);
      },
    );
    final coordinator = PinThumbnailPrefetchCoordinator(repository: repository);
    addTearDown(coordinator.dispose);
    coordinator.updateWindow(Object(), {
      'ahead-1': (_) async {},
      'ahead-2': (_) async {},
    });
    await firstStarted.future.timeout(const Duration(seconds: 3));
    final visible = repository.fetchImageFromUrl(
      'visible',
      'https://images.example/visible',
      false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    releaseFirst.complete();
    await visible;

    expect(started.take(2), ['ahead-1', 'visible']);
  });

  test('a visible consumer promotes its queued look-ahead request', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final started = <String>[];
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      maxConcurrentDownloads: 1,
      getImageUrl: (id) async => 'https://images.example/$id',
      httpGet: (uri) async {
        started.add(uri.pathSegments.single);
        if (uri.pathSegments.single == 'ahead-1') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return http.Response.bytes([1], 200);
      },
    );
    final coordinator = PinThumbnailPrefetchCoordinator(
      repository: repository,
      maxConcurrentRequests: 3,
    );
    addTearDown(coordinator.dispose);
    coordinator.updateWindow(Object(), {
      'ahead-1': (_) async {},
      'ahead-2': (_) async {},
      'target': (_) async {},
    });
    await firstStarted.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final visible = repository.fetchImage('target', false);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    releaseFirst.complete();
    await visible;

    expect(started.take(2), ['ahead-1', 'target']);
  });

  test(
    'a queued prefetch loses foreground priority when its tile leaves',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final started = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.pinThumbnail,
        maxConcurrentDownloads: 1,
        getImageUrl: (id) async => 'https://images.example/$id',
        httpGet: (uri) async {
          started.add(uri.pathSegments.single);
          if (uri.pathSegments.single == 'first') {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return http.Response.bytes([1], 200);
        },
      );
      final coordinator = PinThumbnailPrefetchCoordinator(
        repository: repository,
      );
      addTearDown(coordinator.dispose);
      final first = repository.fetchImage('first', false);
      await firstStarted.future.timeout(const Duration(seconds: 3));
      coordinator.updateWindow(Object(), {'shared': (_) async {}});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final visibleCancellation = ImageRequestCancellation();
      final visible = repository.fetchImage(
        'shared',
        false,
        cancellation: visibleCancellation,
      );
      await Future<void>.delayed(Duration.zero);
      visibleCancellation.cancel();
      final nextVisible = repository.fetchImage('next-visible', false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      releaseFirst.complete();
      await Future.wait([first, visible, nextVisible]);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(started, ['first', 'next-visible', 'shared']);
    },
  );

  test(
    'disposing a repository drops downloads still waiting for a permit',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final requested = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.pinThumbnail,
        maxConcurrentDownloads: 1,
        getImageUrl: (_) async => null,
        httpGet: (uri) async {
          requested.add(uri.pathSegments.single);
          if (uri.pathSegments.single == 'first') {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return http.Response.bytes([1], 200);
        },
      );
      final first = repository.fetchImageFromUrl(
        'first',
        'https://images.example/first',
        false,
      );
      await firstStarted.future.timeout(const Duration(seconds: 3));
      final queued = repository.fetchImageFromUrl(
        'queued',
        'https://images.example/queued',
        false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      repository.dispose();
      releaseFirst.complete();
      await Future.wait([first, queued]);

      expect(requested, ['first']);
    },
  );

  test('a removed grid tile drops its queued thumbnail download', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final requested = <String>[];
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      maxConcurrentDownloads: 1,
      getImageUrl: (id) async => 'https://images.example/$id',
      httpGet: (uri) async {
        requested.add(uri.pathSegments.single);
        if (uri.pathSegments.single == 'first') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return http.Response.bytes([1], 200);
      },
    );
    final first = repository.fetchImage('first', false);
    await firstStarted.future.timeout(const Duration(seconds: 3));

    final container = ProviderContainer(
      overrides: [pinThumbnailRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final tile = container.listen(
      pinThumbnailBytesProvider('tile'),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    tile.close();
    await container.pump();
    releaseFirst.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(requested, ['first']);
  });

  test('a replaced prefetch window drops its queued thumbnail', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final requested = <String>[];
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      maxConcurrentDownloads: 1,
      getImageUrl: (id) async => 'https://images.example/$id',
      httpGet: (uri) async {
        requested.add(uri.pathSegments.single);
        if (uri.pathSegments.single == 'first') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return http.Response.bytes([1], 200);
      },
    );
    final coordinator = PinThumbnailPrefetchCoordinator(repository: repository);
    addTearDown(coordinator.dispose);
    final owner = Object();
    coordinator.updateWindow(owner, {
      'first': (_) async {},
      'queued': (_) async {},
    });
    await firstStarted.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    coordinator.cancelWindow(owner);
    releaseFirst.complete();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(requested, ['first']);
  });

  test('an active canceled prefetch holds its slot until it settles', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      getImageUrl: (id) async {
        if (id == 'first') {
          firstStarted.complete();
          await releaseFirst.future;
        } else if (!secondStarted.isCompleted) {
          secondStarted.complete();
        }
        return null;
      },
    );
    final coordinator = PinThumbnailPrefetchCoordinator(
      repository: repository,
      maxConcurrentRequests: 1,
    );
    addTearDown(coordinator.dispose);
    final owner = Object();
    coordinator.updateWindow(owner, {'first': (_) async {}});
    await firstStarted.future.timeout(const Duration(seconds: 3));
    coordinator.updateWindow(owner, {'second': (_) async {}});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(secondStarted.isCompleted, isFalse);

    releaseFirst.complete();
    await secondStarted.future.timeout(const Duration(seconds: 3));
  });

  test(
    'a restarted prefetch waits for its canceled request to settle',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondStarted = Completer<void>();
      var calls = 0;
      final repository = ImageRepository(
        db: database,
        type: ImageType.pinThumbnail,
        getImageUrl: (_) async {
          calls++;
          if (calls == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          } else {
            secondStarted.complete();
          }
          return null;
        },
      );
      final coordinator = PinThumbnailPrefetchCoordinator(
        repository: repository,
      );
      addTearDown(coordinator.dispose);
      final owner = Object();
      coordinator.updateWindow(owner, {'same': (_) async {}});
      await firstStarted.future.timeout(const Duration(seconds: 3));
      coordinator.cancelWindow(owner);
      coordinator.updateWindow(owner, {'same': (_) async {}});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, 1);

      releaseFirst.complete();
      await secondStarted.future.timeout(const Duration(seconds: 3));
      expect(calls, 2);
    },
  );

  test('removing a tile aborts its active image HTTP request', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final started = Completer<http.BaseRequest>();
    final responseBody = StreamController<List<int>>();
    addTearDown(responseBody.close);

    await http.runWithClient(
      () async {
        final repository = ImageRepository(
          db: database,
          type: ImageType.pinThumbnail,
          getImageUrl: (_) async => 'https://images.example/active',
        );
        final container = ProviderContainer(
          overrides: [
            pinThumbnailRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final tile = container.listen(
          pinThumbnailBytesProvider('active'),
          (_, _) {},
          fireImmediately: true,
        );
        final request = await started.future.timeout(
          const Duration(seconds: 3),
        );
        tile.close();
        await container.pump();

        expect(request, isA<http.Abortable>());
        await (request as http.Abortable).abortTrigger!.timeout(
          const Duration(seconds: 1),
        );
      },
      () => MockClient.streaming((request, _) async {
        started.complete(request);
        return http.StreamedResponse(responseBody.stream, 200);
      }),
    );
  });

  test('canceling a prefetch window aborts its active HTTP request', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final started = Completer<http.BaseRequest>();
    final responseBody = StreamController<List<int>>();
    addTearDown(responseBody.close);

    await http.runWithClient(
      () async {
        final repository = ImageRepository(
          db: database,
          type: ImageType.pinThumbnail,
          getImageUrl: (_) async => 'https://images.example/ahead',
        );
        final coordinator = PinThumbnailPrefetchCoordinator(
          repository: repository,
        );
        addTearDown(coordinator.dispose);
        final owner = Object();
        coordinator.updateWindow(owner, {'ahead': (_) async {}});
        final request = await started.future.timeout(
          const Duration(seconds: 3),
        );
        coordinator.cancelWindow(owner);

        expect(request, isA<http.Abortable>());
        await (request as http.Abortable).abortTrigger!.timeout(
          const Duration(seconds: 1),
        );
      },
      () => MockClient.streaming((request, _) async {
        started.complete(request);
        return http.StreamedResponse(responseBody.stream, 200);
      }),
    );
  });

  test('a shared download continues until its last owner leaves', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final started = Completer<http.BaseRequest>();
    final responseBody = StreamController<List<int>>();
    addTearDown(responseBody.close);

    await http.runWithClient(
      () async {
        final repository = ImageRepository(
          db: database,
          type: ImageType.pinThumbnail,
          getImageUrl: (_) async => 'https://images.example/shared',
        );
        final lookAhead = ImageRequestCancellation();
        final visible = ImageRequestCancellation();
        final background = repository.fetchImage(
          'shared',
          false,
          priority: ImageRequestPriority.background,
          cancellation: lookAhead,
        );
        final request = await started.future.timeout(
          const Duration(seconds: 3),
        );
        final foreground = repository.fetchImage(
          'shared',
          false,
          cancellation: visible,
        );
        await Future<void>.delayed(Duration.zero);

        var aborted = false;
        final abortTrigger = (request as http.Abortable).abortTrigger!;
        abortTrigger.then((_) => aborted = true);
        lookAhead.cancel();
        await Future<void>.delayed(Duration.zero);
        expect(aborted, isFalse);

        visible.cancel();
        await abortTrigger.timeout(const Duration(seconds: 1));
        responseBody.close();
        expect(await Future.wait([background, foreground]), [null, null]);
      },
      () => MockClient.streaming((request, _) async {
        started.complete(request);
        return http.StreamedResponse(responseBody.stream, 200);
      }),
    );
  });

  test('an abandoned image response cannot populate the cache', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final started = Completer<void>();
    final release = Completer<void>();
    final repository = ImageRepository(
      db: database,
      type: ImageType.pinThumbnail,
      getImageUrl: (_) async => 'https://images.example/abandoned',
      httpGet: (_) async {
        started.complete();
        await release.future;
        return http.Response.bytes([1], 200);
      },
    );
    final cancellation = ImageRequestCancellation();
    final fetch = repository.fetchImage(
      'abandoned',
      false,
      cancellation: cancellation,
    );
    await started.future.timeout(const Duration(seconds: 3));
    cancellation.cancel();
    release.complete();

    expect(await fetch, isNull);
    expect(await repository.get('abandoned'), isNull);
  });

  test('timed-out transport keeps its slot until abort settles', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final slowStarted = Completer<http.BaseRequest>();
    final releaseAbort = Completer<void>();
    final fastStarted = Completer<void>();

    await http.runWithClient(
      () async {
        final repository = ImageRepository(
          db: database,
          type: ImageType.pinThumbnail,
          getImageUrl: (_) async => null,
          maxConcurrentDownloads: 1,
          httpTimeout: const Duration(milliseconds: 25),
        );
        final slow = repository.fetchImageFromUrl(
          'slow',
          'https://images.example/slow',
          false,
          fallbackToEndpoint: false,
        );
        final request = await slowStarted.future.timeout(
          const Duration(seconds: 3),
        );
        await (request as http.Abortable).abortTrigger!.timeout(
          const Duration(seconds: 1),
        );

        final fast = repository.fetchImageFromUrl(
          'fast',
          'https://images.example/fast',
          false,
          fallbackToEndpoint: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(fastStarted.isCompleted, isFalse);
        releaseAbort.complete();
        expect(await slow, isNull);
        expect(await fast, [1]);
      },
      () => MockClient.streaming((request, _) async {
        if (request.url.pathSegments.single == 'slow') {
          slowStarted.complete(request);
          await (request as http.Abortable).abortTrigger!;
          await releaseAbort.future;
          throw StateError('transport aborted');
        }
        fastStarted.complete();
        return http.StreamedResponse(Stream.value([1]), 200);
      }),
    );
  });

  test('a timed-out replacement request aborts its transport', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final started = Completer<http.BaseRequest>();

    await http.runWithClient(
      () async {
        final repository = ImageRepository(
          db: database,
          type: ImageType.pinThumbnail,
          getImageUrl: (_) async => null,
          httpTimeout: const Duration(milliseconds: 25),
        );
        final replacement = repository.overrideUrl(
          'replacement',
          'https://images.example/replacement',
          false,
        );
        final replacementExpectation = expectLater(
          replacement,
          throwsA(isA<Exception>()),
        );
        final request = await started.future.timeout(
          const Duration(seconds: 3),
        );
        await (request as http.Abortable).abortTrigger!.timeout(
          const Duration(seconds: 1),
        );
        await replacementExpectation;
      },
      () => MockClient.streaming((request, _) async {
        started.complete(request);
        await (request as http.Abortable).abortTrigger!;
        throw StateError('transport aborted');
      }),
    );
  });

  test('image repository providers use four times the cache capacity', () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final apiClient = ApiClient();
    final container = ProviderContainer(
      overrides: [
        accountDatabaseProvider.overrideWithValue(database),
        groupApiProvider.overrideWithValue(GroupsApi(apiClient)),
        userApiProvider.overrideWithValue(UsersApi(apiClient)),
        pinApiProvider.overrideWithValue(PinsApi(apiClient)),
      ],
    );
    addTearDown(container.dispose);

    final expectedLimits = <IImageRepository, int>{
      container.read(groupProfileRepoProvider): 400,
      container.read(groupProfileSmallRepoProvider): 400,
      container.read(groupPinImageRepoProvider): 200,
      container.read(userImageSmallRepoProvider): 2000,
      container.read(userImageRepoProvider): 200,
      container.read(pinImageRepositoryProvider): 800,
    };

    for (final entry in expectedLimits.entries) {
      expect((entry.key as ImageRepository).maxItems, entry.value);
    }
  });

  for (final suppliedUrl in [false, true]) {
    test(
      'retiring an image repository during a cache read returns no bytes ($suppliedUrl)',
      () async {
        final pause = _PauseImageTouch();
        final database = AppDatabase(
          NativeDatabase.memory().interceptWith(pause),
        );
        addTearDown(database.close);
        final repository = _repository(database, ImageType.pin);
        await repository.addImage('pin', Uint8List.fromList([1, 2]), true);
        pause.enabled = true;
        final read = suppliedUrl
            ? repository.fetchImageFromUrl(
                'pin',
                'https://example.com/image',
                true,
              )
            : repository.fetchImage('pin', true);
        await pause.started.future;
        repository.dispose();
        pause.release.complete();
        expect(await read, isNull);
      },
    );
  }

  test('image cache operations keep image types isolated', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final largeRepository = _repository(database, ImageType.group);
    final smallRepository = _repository(database, ImageType.groupSmall);

    await largeRepository.addImage('group-1', Uint8List.fromList([1]), false);
    await smallRepository.addImage('group-1', Uint8List.fromList([2]), false);

    expect((await largeRepository.get('group-1'))!.image, [1]);
    expect((await smallRepository.get('group-1'))!.image, [2]);

    await largeRepository.delete('group-1');

    expect(await largeRepository.get('group-1'), isNull);
    expect(await smallRepository.get('group-1'), isNotNull);
  });

  for (final initialBytes in [
    <int>[],
    <int>[1],
  ]) {
    test(
      'refresh publishes bytes for a retained expired cache ($initialBytes)',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = ImageRepository(
          db: database,
          type: ImageType.groupSmall,
          getImageUrl: (_) async => 'https://example.com/image',
          httpGet: (_) async => http.Response.bytes([2], 200),
        );
        await repository.ready;
        await repository.doPut(
          ImageEntity(
            id: 'group-1',
            type: ImageType.groupSmall,
            image: Uint8List.fromList(initialBytes),
            keepAlive: true,
            ttl: DateTime.now().subtract(const Duration(minutes: 1)),
            onlySession: false,
          ),
        );
        final updated = Completer<Uint8List>();
        final subscription = repository.watchImageBytes('group-1').listen((
          bytes,
        ) {
          if (bytes != null &&
              bytes.length == 1 &&
              bytes.single == 2 &&
              !updated.isCompleted) {
            updated.complete(bytes);
          }
        });
        addTearDown(subscription.cancel);

        expect(await repository.fetchImage('group-1', false), [2]);

        final cached = await repository.get('group-1');
        expect(cached!.image, [2]);
        expect(cached.keepAlive, isTrue);
        expect(await updated.future.timeout(const Duration(seconds: 2)), [2]);
      },
    );
  }

  test('expired empty entries are fetched again', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var urlLookups = 0;
    final repository = ImageRepository(
      db: database,
      type: ImageType.groupSmall,
      getImageUrl: (_) async {
        urlLookups++;
        return null;
      },
      maxItems: 10,
      ttlDuration: const Duration(days: 7),
    );
    await repository.ready;

    await repository.doPut(
      ImageEntity(
        id: 'group-1',
        type: ImageType.groupSmall,
        image: Uint8List(0),
        ttl: DateTime.now().subtract(const Duration(minutes: 1)),
        onlySession: false,
      ),
    );

    await repository.fetchImage('group-1', false);

    expect(urlLookups, 1);
  });

  test(
    'URL image loads revalidate expired bytes and promote keep alive',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var endpointLookups = 0;
      final requestedPaths = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.groupSmall,
        getImageUrl: (_) async {
          endpointLookups++;
          return 'https://example.com/endpoint';
        },
        httpGet: (uri) async {
          requestedPaths.add(uri.path);
          return http.Response.bytes([2], 200);
        },
        maxItems: 10,
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.groupSmall,
          image: Uint8List.fromList([1]),
          ttl: DateTime.now().subtract(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final image = await repository.fetchImageFromUrl(
        'group-1',
        'https://example.com/search',
        true,
      );

      expect(image, [2]);
      expect(requestedPaths, ['/search']);
      expect(endpointLookups, 0);
      expect((await repository.get('group-1'))!.keepAlive, isTrue);
    },
  );

  test(
    'an expired photo URL cannot poison a concurrent pin batch read',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final expiredUrlStarted = Completer<void>();
      final releaseExpiredUrl = Completer<void>();
      final batches = <List<BatchReadItem>>[];
      final batchReads = BatchReadCoalescer(
        window: const Duration(milliseconds: 200),
        read: (items) async {
          batches.add(items);
          if (items.any((item) => item.id.startsWith('photo:'))) {
            throw StateError('The pin image endpoint rejects photo ids.');
          }
          return [
            for (final item in items)
              BatchReadResult(
                kind: batchResultKind(item.kind),
                id: item.id,
                status: 200,
                imageUrl: 'https://example.com/pin-thumbnail',
              ),
          ];
        },
      );
      addTearDown(batchReads.dispose);

      final repository = ImageRepository(
        db: database,
        type: ImageType.pinThumbnail,
        getImageUrl: (id) async => (await batchReads.readKey(
          BatchReadKey(BatchReadKind.pinImageThumbnail, id),
        )).imageUrl,
        httpGet: (uri) async {
          if (uri.path == '/expired-photo') {
            expiredUrlStarted.complete();
            await releaseExpiredUrl.future;
            return http.Response.bytes([], 403);
          }
          return http.Response.bytes([9], 200);
        },
      );
      await repository.ready;

      final photoFetch = repository.fetchImageFromUrl(
        'photo:update-1',
        'https://example.com/expired-photo',
        false,
        fallbackToEndpoint: false,
      );
      await expiredUrlStarted.future;
      final pinFetch = repository.fetchImage('pin-1', false);
      releaseExpiredUrl.complete();

      final results = await Future.wait([photoFetch, pinFetch]);

      expect(results, [
        null,
        [9],
      ]);
      expect(batches, hasLength(1));
      expect(batches.single.map((item) => item.id), ['pin-1']);
    },
  );

  test(
    'URL failures bypass fresh empty cache rows for endpoint fallback',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var endpointLookups = 0;
      final requestedPaths = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.groupSmall,
        getImageUrl: (_) async {
          endpointLookups++;
          return 'https://example.com/endpoint';
        },
        httpGet: (uri) async {
          requestedPaths.add(uri.path);
          if (uri.path == '/search') return http.Response.bytes([], 500);
          return http.Response.bytes([3], 200);
        },
        maxItems: 10,
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.groupSmall,
          image: Uint8List(0),
          ttl: DateTime.now().add(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final image = await repository.fetchImageFromUrl(
        'group-1',
        'https://example.com/search',
        false,
      );

      expect(image, [3]);
      expect(requestedPaths, ['/search', '/endpoint']);
      expect(endpointLookups, 1);
      expect((await repository.get('group-1'))!.image, [3]);
    },
  );

  test('migrates legacy image rows to stable composite keys', () async {
    final nativeDatabase = sqlite3.openInMemory();
    final initialDatabase = AppDatabase(
      NativeDatabase.opened(nativeDatabase, closeUnderlyingOnClose: false),
    );
    await initialDatabase.customSelect('SELECT 1').get();
    await initialDatabase.close();

    nativeDatabase.execute('DROP TABLE image_entities');
    nativeDatabase.execute('''
      CREATE TABLE image_entities (
        isar_id INTEGER NOT NULL PRIMARY KEY,
        ttl INTEGER NOT NULL,
        hits INTEGER NOT NULL DEFAULT 1,
        keep_alive INTEGER NOT NULL DEFAULT 0,
        only_session INTEGER NOT NULL DEFAULT 0,
        id TEXT NOT NULL,
        type INTEGER NOT NULL,
        image BLOB
      )
    ''');
    nativeDatabase.execute(
      'INSERT INTO image_entities '
      '(isar_id, ttl, id, type, image) VALUES (?, ?, ?, ?, ?)',
      [
        1,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'group-1',
        4,
        [1],
      ],
    );
    nativeDatabase.execute('ALTER TABLE pin_entities DROP COLUMN title');
    nativeDatabase.execute('ALTER TABLE pin_entities DROP COLUMN is_gone');
    nativeDatabase.execute('ALTER TABLE group_entities DROP COLUMN pin_style');
    nativeDatabase.execute(
      'ALTER TABLE user_entities DROP COLUMN selected_batch_color',
    );
    nativeDatabase.execute('PRAGMA user_version = 1');

    final migratedDatabase = AppDatabase(
      NativeDatabase.opened(nativeDatabase, closeUnderlyingOnClose: false),
    );
    addTearDown(() async {
      await migratedDatabase.close();
      nativeDatabase.close();
    });

    final rows = await migratedDatabase
        .select(migratedDatabase.imageEntities)
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.cacheKey, 'groupSmall:group-1');
    expect(rows.single.type, ImageType.groupSmall);
    final groupColumns = await migratedDatabase
        .customSelect('PRAGMA table_info(group_entities)')
        .get();
    expect(
      groupColumns.map((column) => column.read<String>('name')),
      contains('pin_style'),
    );
  });

  test('active image watchers are protected from cache pruning', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall, maxItems: 1);

    final ids = ['active', 'other-1', 'other-2']
      ..sort(
        (left, right) =>
            ImageEntity(
              id: left,
              type: ImageType.groupSmall,
              image: Uint8List(0),
              ttl: DateTime.now(),
              onlySession: false,
            ).isarId.compareTo(
              ImageEntity(
                id: right,
                type: ImageType.groupSmall,
                image: Uint8List(0),
                ttl: DateTime.now(),
                onlySession: false,
              ).isarId,
            ),
      );

    final activeId = ids.first;
    final watcher = repository.watchImageBytes(activeId).listen((_) {});
    addTearDown(watcher.cancel);

    await repository.addImage(activeId, Uint8List.fromList([1]), false);
    await repository.addImage(ids[1], Uint8List.fromList([2]), false);
    await repository.addImage(ids[2], Uint8List.fromList([3]), false);

    expect((await repository.get(activeId))!.image, [1]);
  });

  test('metadata-only updates preserve the watched byte buffer', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall);
    final firstImage = Completer<Uint8List>();

    final subscription = repository.watchImageBytes('group-1').listen((image) {
      if (image == null) return;
      if (!firstImage.isCompleted) {
        firstImage.complete(image);
      }
    });
    addTearDown(subscription.cancel);

    await repository.addImage('group-1', Uint8List.fromList([1, 2, 3]), false);
    final first = await firstImage.future;

    final fetched = await repository.fetchImage('group-1', false);

    expect(identical(first, fetched), isTrue);
  });

  test('metadata-only updates do not re-emit watched image bytes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall);
    final iterator = StreamIterator<Uint8List?>(
      repository.watchImageBytes('group-1'),
    );
    addTearDown(iterator.cancel);

    await repository.addImage('group-1', Uint8List.fromList([1, 2, 3]), false);
    while (await iterator.moveNext() && iterator.current == null) {}
    expect(iterator.current, isNotNull);

    await repository.fetchImage('group-1', false);

    final hasSecondEmission = await iterator.moveNext().timeout(
      const Duration(milliseconds: 100),
      onTimeout: () => false,
    );
    expect(hasSecondEmission, isFalse);
  });

  for (final retainedBeforeFetch in [false, true]) {
    test(
      'a late public fetch cannot overwrite a joined image cache (retained: $retainedBeforeFetch)',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);

        final publicRequestStarted = Completer<void>();
        final releasePublicResponse = Completer<void>();
        final releaseJoinedResponse = Completer<void>();
        final repository = ImageRepository(
          db: database,
          type: ImageType.group,
          getImageUrl: (_) async => 'https://example.com/public',
          httpGet: (uri) async {
            if (uri.path == '/public') {
              if (!publicRequestStarted.isCompleted) {
                publicRequestStarted.complete();
              }
              await releasePublicResponse.future;
              return http.Response.bytes([1], 200);
            }
            await releaseJoinedResponse.future;
            return http.Response.bytes([2], 200);
          },
          ttlDuration: const Duration(days: 7),
        );
        await repository.ready;

        if (retainedBeforeFetch) {
          await repository.doPut(
            ImageEntity(
              id: 'group-1',
              type: ImageType.group,
              image: Uint8List.fromList([0]),
              keepAlive: true,
              ttl: DateTime.now().subtract(const Duration(minutes: 1)),
              onlySession: false,
            ),
          );
        }

        final joinedOverride = repository.overrideUrl(
          'group-1',
          'https://example.com/joined',
          true,
        );
        final publicFetch = repository.fetchImage('group-1', false);
        await publicRequestStarted.future;
        final joinedFetch = repository.fetchImage('group-1', true);

        releaseJoinedResponse.complete();
        await joinedOverride;
        expect((await repository.get('group-1'))!.image, [2]);
        expect((await repository.get('group-1'))!.keepAlive, isTrue);

        releasePublicResponse.complete();
        await publicFetch;
        await joinedFetch;

        final cached = await repository.get('group-1');
        expect(cached!.image, [2]);
        expect(cached.keepAlive, isTrue);
      },
    );
  }

  test(
    'a late fetch cannot replace bytes from a successful image override',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final oldRequestStarted = Completer<void>();
      final releaseOldResponse = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async => 'https://example.com/old',
        httpGet: (uri) async {
          if (uri.path == '/old') {
            oldRequestStarted.complete();
            await releaseOldResponse.future;
            return http.Response.bytes([1], 200);
          }
          return http.Response.bytes([2], 200);
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;

      final oldFetch = repository.fetchImage('group-1', true);
      await oldRequestStarted.future;
      await repository.overrideUrl('group-1', 'https://example.com/new', true);
      releaseOldResponse.complete();
      await oldFetch;

      expect((await repository.get('group-1'))!.image, [2]);
    },
  );

  test(
    'only the latest successful image override can replace cached bytes',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final firstRequestStarted = Completer<void>();
      final releaseFirstResponse = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async => null,
        httpGet: (uri) async {
          if (uri.path == '/first') {
            firstRequestStarted.complete();
            await releaseFirstResponse.future;
            return http.Response.bytes([1], 200);
          }
          return http.Response.bytes([2], 200);
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;

      final firstOverride = repository.overrideUrl(
        'group-1',
        'https://example.com/first',
        true,
      );
      await firstRequestStarted.future;
      await repository.overrideUrl(
        'group-1',
        'https://example.com/second',
        true,
      );
      releaseFirstResponse.complete();
      await firstOverride;

      expect((await repository.get('group-1'))!.image, [2]);
    },
  );

  test('a shared empty fetch promotes the image cache to keep alive', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final urlLookupStarted = Completer<void>();
    final releaseUrlLookup = Completer<void>();
    final repository = ImageRepository(
      db: database,
      type: ImageType.group,
      getImageUrl: (_) async {
        urlLookupStarted.complete();
        await releaseUrlLookup.future;
        return null;
      },
      ttlDuration: const Duration(days: 7),
    );
    await repository.ready;

    final publicFetch = repository.fetchImage('group-1', false);
    await urlLookupStarted.future;
    final joinedFetch = repository.fetchImage('group-1', true);

    releaseUrlLookup.complete();
    await publicFetch;
    await joinedFetch;

    final cached = await repository.get('group-1');
    expect(cached!.image, isEmpty);
    expect(cached.keepAlive, isTrue);
  });

  test(
    'a deduplicated stale fetch promotes the image cache to keep alive',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final urlLookupStarted = Completer<void>();
      final releaseUrlLookup = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async {
          urlLookupStarted.complete();
          await releaseUrlLookup.future;
          return null;
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.group,
          image: Uint8List.fromList([1]),
          ttl: DateTime.now().subtract(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final publicFetch = repository.fetchImage('group-1', false);
      final joinedFetch = repository.fetchImage('group-1', true);
      await urlLookupStarted.future;

      releaseUrlLookup.complete();
      await publicFetch;
      await joinedFetch;

      expect((await repository.get('group-1'))!.keepAlive, isTrue);
    },
  );

  test(
    'a failed override does not discard an image fetch already in flight',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final publicRequestStarted = Completer<void>();
      final releasePublicResponse = Completer<void>();
      final releaseOverrideResponse = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async => 'https://example.com/public',
        httpGet: (uri) async {
          if (uri.path == '/public') {
            publicRequestStarted.complete();
            await releasePublicResponse.future;
            return http.Response.bytes([1], 200);
          }
          await releaseOverrideResponse.future;
          return http.Response.bytes([], 500);
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;

      final publicFetch = repository.fetchImage('group-1', false);
      await publicRequestStarted.future;

      releasePublicResponse.complete();
      final failedOverride = repository.overrideUrl(
        'group-1',
        'https://example.com/joined',
        true,
      );
      releaseOverrideResponse.complete();

      await expectLater(failedOverride, throwsException);
      await publicFetch;

      expect((await repository.get('group-1'))!.image, [1]);
    },
  );
}

ImageRepository _repository(
  AppDatabase database,
  ImageType type, {
  int maxItems = 10,
}) {
  return ImageRepository(
    db: database,
    type: type,
    getImageUrl: (_) async => null,
    maxItems: maxItems,
    ttlDuration: const Duration(days: 7),
  );
}

class _PauseImageTouch extends QueryInterceptor {
  bool enabled = false;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (enabled) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    return executor.runUpdate(statement, args);
  }
}
