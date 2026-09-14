import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'logout rebuilds reject batch reads without sending anonymous requests',
    () async {
      dotenv.loadFromString(envString: 'API_HOST=https://example.test');
      var batches = 0;
      await http.runWithClient(
        () async {
          final container = ProviderContainer(
            overrides: [
              globalDataServiceProvider.overrideWith(_BatchSession.new),
            ],
          );
          addTearDown(container.dispose);
          const key = BatchReadKey(BatchReadKind.user, 'user');
          final session = container.read(
            globalDataServiceProvider.notifier,
          ) as _BatchSession;
          await container.read(batchReadCoalescerProvider).readKey(key);
          expect(batches, 1);
          session.setUser(null);
          await expectLater(
            container.read(batchReadCoalescerProvider).readKey(key),
            throwsA(isA<BatchReadDisposedException>()),
          );
          expect(batches, 1);
          session.setUser('user');
          await container.read(batchReadCoalescerProvider).readKey(key);
          expect(batches, 2);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            return http.Response(
              jsonEncode({
                'accessToken': 'test-access',
                'refreshToken': 'test-refresh',
                'userId': 'user',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          batches++;
          return http.Response(
            jsonEncode({
              'results': [
                {'kind': 'user', 'id': 'user', 'status': 200},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
    },
  );

  test('session identity changes when the refresh token rotates', () {
    const oldSession = SessionIdentity(
      userId: 'user',
      refreshToken: 'secret-refresh-token',
    );
    expect(
      oldSession,
      isNot(const SessionIdentity(userId: 'user', refreshToken: 'new')),
    );
    expect(oldSession.toString(), isNot(contains('secret-refresh-token')));
  });

  test(
    'uses the generated transport and deserializes image URL results',
    () async {
      final api = _BatchApi();
      final transport = BatchReadApiTransport(api);

      final results = await transport([
        BatchReadItem(kind: BatchReadItemKindEnum.pinImage, id: 'pin-1'),
      ]);

      expect(api.requests.single.requests.single.id, 'pin-1');
      expect(results.single.imageUrl, 'https://images.example/pin-1');
    },
  );

  test(
    'coalesces distinct kinds and duplicate consumers into one request',
    () async {
      final requests = <List<BatchReadItem>>[];
      final loader = BatchReadCoalescer(
        window: Duration.zero,
        read: (items) async {
          requests.add(items);
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
      );
      addTearDown(loader.dispose);

      final values = await Future.wait([
        loader.readKey(const BatchReadKey(BatchReadKind.pinImage, 'pin-1')),
        loader.readKey(
          const BatchReadKey(BatchReadKind.userImageSmall, 'user-1'),
        ),
        loader.readKey(const BatchReadKey(BatchReadKind.pinImage, 'pin-1')),
      ]);

      expect(requests, hasLength(1));
      expect(requests.single.map((item) => '${item.kind.value}:${item.id}'), [
        'pinImage:pin-1',
        'userImageSmall:user-1',
      ]);
      expect(values.map((value) => value.id), ['pin-1', 'user-1', 'pin-1']);
    },
  );

  test('splits more than one hundred keys into bounded requests', () async {
    final requests = <List<BatchReadItem>>[];
    final loader = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async {
        requests.add(items);
        return items
            .map(
              (item) => BatchReadResult(
                kind: batchResultKind(item.kind),
                id: item.id,
                status: 200,
              ),
            )
            .toList();
      },
    );
    addTearDown(loader.dispose);

    await Future.wait(
      List.generate(
        101,
        (index) => loader.readKey(BatchReadKey(BatchReadKind.user, '$index')),
      ),
    );

    expect(requests.map((request) => request.length), [100, 1]);
  });

  test('joins a duplicate consumer after its batch has started', () async {
    final response = Completer<List<BatchReadResult>>();
    var calls = 0;
    final loader = BatchReadCoalescer(
      window: Duration.zero,
      read: (_) {
        calls++;
        return response.future;
      },
    );
    addTearDown(loader.dispose);

    final first = loader.readKey(
      const BatchReadKey(BatchReadKind.groupImage, 'group-1'),
    );
    await Future<void>.delayed(Duration.zero);
    final second = loader.readKey(
      const BatchReadKey(BatchReadKind.groupImage, 'group-1'),
    );
    response.complete([
      BatchReadResult(
        kind: BatchReadResultKindEnum.groupImage,
        id: 'group-1',
        status: 200,
      ),
    ]);

    await expectLater(first, completes);
    await expectLater(second, completes);
    expect(calls, 1);
  });

  test('propagates an item failure and allows a later retry', () async {
    var attempts = 0;
    final loader = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async {
        attempts++;
        return [
          BatchReadResult(
            kind: BatchReadResultKindEnum.pinLikes,
            id: 'pin-1',
            status: attempts == 1 ? 503 : 200,
          ),
        ];
      },
    );
    addTearDown(loader.dispose);

    await expectLater(
      loader.readKey(const BatchReadKey(BatchReadKind.pinLikes, 'pin-1')),
      throwsA(isA<BatchReadFailure>()),
    );
    final result = await loader.readKey(
      const BatchReadKey(BatchReadKind.pinLikes, 'pin-1'),
    );

    expect(result.status, 200);
    expect(attempts, 2);
  });

  test(
    'disposal fails pending consumers and ignores a late response',
    () async {
      final response = Completer<List<BatchReadResult>>();
      final loader = BatchReadCoalescer(
        window: Duration.zero,
        read: (_) => response.future,
      );
      final read = loader.readKey(
        const BatchReadKey(BatchReadKind.groupImage, 'group-1'),
      );
      await Future<void>.delayed(Duration.zero);

      loader.dispose();
      response.complete([
        BatchReadResult(
          kind: BatchReadResultKindEnum.groupImage,
          id: 'group-1',
          status: 200,
          imageUrl: 'https://images.example/stale',
        ),
      ]);

      await expectLater(read, throwsA(isA<BatchReadDisposedException>()));
    },
  );

  test('retains supplied image URLs per session with bounded eviction', () {
    final registry = SuppliedImageUrlRegistry(maxEntries: 2);
    registry.register(BatchReadKind.pinImage, 'old', 'https://images/old');
    registry.register(BatchReadKind.pinImage, 'kept', 'https://images/kept');
    expect(
      registry.lookup(BatchReadKind.pinImage, 'old'),
      'https://images/old',
    );
    registry.register(BatchReadKind.pinImage, 'new', 'https://images/new');

    expect(
      registry.lookup(BatchReadKind.pinImage, 'old'),
      'https://images/old',
    );
    expect(registry.lookup(BatchReadKind.pinImage, 'kept'), isNull);
    expect(
      registry.lookup(BatchReadKind.pinImage, 'new'),
      'https://images/new',
    );
  });
}

class _BatchApi extends BatchApi {
  _BatchApi() : super(ApiClient());

  final requests = <BatchReadRequest>[];

  @override
  Future<BatchReadResponse?> batchRead(BatchReadRequest request) async {
    requests.add(request);
    return BatchReadResponse.fromJson({
      'results': [
        {
          'kind': 'pinImage',
          'id': 'pin-1',
          'status': 200,
          'imageUrl': 'https://images.example/pin-1',
        },
      ],
    });
  }
}

class _BatchSession extends GlobalDataService {
  @override
  GlobalDataDto build() => const GlobalDataDto(
    userId: 'user',
    refreshToken: 'test-refresh',
    cameras: [],
  );
  void setUser(String? userId) {
    state = GlobalDataDto(
      userId: userId,
      refreshToken: userId == null ? null : 'test-refresh',
      cameras: const [],
    );
  }
}
