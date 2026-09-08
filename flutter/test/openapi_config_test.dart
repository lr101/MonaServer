import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

void main() {
  setUp(
    () => dotenv.loadFromString(envString: 'API_HOST=https://example.test'),
  );
  test(
    'closing a session clears its token and rejects a late refresh',
    () async {
      final started = Completer<void>();
      final refresh = Completer<String?>();
      final manager = AccessTokenManager(
        initialAccessToken: 'old-token',
        refreshAccessToken: () {
          started.complete();
          return refresh.future;
        },
      );
      final resources = _resources(manager, _RecordingClient([200]));
      final pending = manager.refresh(force: true);
      final rejected = expectLater(
        pending,
        throwsA(isA<http.ClientException>()),
      );
      await started.future;
      resources.close();
      refresh.complete('late-token');
      await rejected;
      expect(manager.accessToken, isEmpty);
      await expectLater(
        manager.refresh(),
        throwsA(isA<http.ClientException>()),
      );
    },
  );

  test(
    'closed clients reject active and queued requests before another send',
    () async {
      final started = Completer<void>();
      final response = Completer<http.StreamedResponse>();
      var sends = 0;
      final inner = _CallbackClient((_) {
        sends++;
        if (!started.isCompleted) started.complete();
        return response.future;
      });
      final manager = AccessTokenManager(
        refreshAccessToken: () async => 'token',
      );
      final resources = _resources(manager, inner);
      final first = resources.apiClient.client.get(
        Uri.parse('https://example.test/one'),
      );
      final second = resources.apiClient.client.get(
        Uri.parse('https://example.test/two'),
      );
      final rejected = [
        expectLater(first, throwsA(isA<http.ClientException>())),
        expectLater(second, throwsA(isA<http.ClientException>())),
      ];
      await started.future;
      resources.close();
      response.complete(_response(200));
      await Future.wait(rejected);
      expect(sends, 1);
      await expectLater(
        resources.apiClient.client.get(Uri.parse('https://example.test/three')),
        throwsA(isA<http.ClientException>()),
      );
      expect(sends, 1);
    },
  );

  test(
    'closing a session interrupts a response body already being read',
    () async {
      final listening = Completer<void>();
      final body = StreamController<List<int>>(onListen: listening.complete);
      final manager = AccessTokenManager(
        refreshAccessToken: () async => 'token',
      );
      final resources = _resources(
        manager,
        _CallbackClient((_) async {
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      final result = resources.apiClient.client.get(
        Uri.parse('https://example.test/pins'),
      );
      final rejected = expectLater(
        result,
        throwsA(isA<http.ClientException>()),
      );
      await listening.future;
      body.add(utf8.encode('old account data'));
      resources.close();
      await body.close();
      await rejected;
    },
  );

  for (final sourceCompletes in [false, true]) {
    test(
      'stream listeners reject queued bytes after closure (source complete: $sourceCompletes)',
      () async {
        final body = StreamController<List<int>>(sync: true);
        final manager = AccessTokenManager(
          refreshAccessToken: () async => 'token',
        );
        final resources = _resources(
          manager,
          _CallbackClient((_) async {
            return http.StreamedResponse(body.stream, 200);
          }),
        );
        final response = await resources.apiClient.client.send(
          http.Request('GET', Uri.parse('https://example.test/pins')),
        );
        final finished = Completer<void>();
        final afterClose = <int>[];
        final errors = <Object>[];
        var closed = false;
        response.stream.listen(
          (bytes) {
            if (closed) afterClose.addAll(bytes);
          },
          onError: (Object error) {
            errors.add(error);
          },
          onDone: finished.complete,
        );

        // Queue bytes before closure, without yielding to the wrapper's listener.
        body.add([42]);
        if (sourceCompletes) unawaited(body.close());
        closed = true;
        resources.close();
        await finished.future;
        await body.close();
        expect(afterClose, isEmpty);
        expect(errors, [isA<http.ClientException>()]);
      },
    );
  }

  test('switching accounts never reuses the previous access token', () async {
    final headers = <String?>[];
    final refreshedUsers = <String>[];
    await http.runWithClient(
      () async {
        final container = ProviderContainer(
          overrides: [globalDataServiceProvider.overrideWith(_Session.new)],
        );
        addTearDown(container.dispose);
        final first = container.read(openApiConfigProvider);
        await first.client.get(Uri.parse('https://example.test/pins'));
        (container.read(globalDataServiceProvider.notifier) as _Session)
            .setSession('second');
        final second = container.read(openApiConfigProvider);
        await second.client.get(Uri.parse('https://example.test/pins'));
        expect(refreshedUsers, ['first', 'second']);
        expect(headers, ['Bearer first-access', 'Bearer second-access']);
      },
      () => _CallbackClient((request) async {
        if (request.url.path.contains('refresh')) {
          final payload = jsonDecode(
            utf8.decode(await request.finalize().toBytes()),
          ) as Map<String, dynamic>;
          final user = payload['userId'] as String;
          refreshedUsers.add(user);
          return _jsonResponse({
            'accessToken': '$user-access',
            'refreshToken': '$user-refresh',
            'userId': user,
          });
        }
        headers.add(request.headers['Authorization']);
        return _response(200);
      }),
    );
  });

  test('camera metadata changes preserve the configured session client', () {
    final container = ProviderContainer(
      overrides: [globalDataServiceProvider.overrideWith(_Session.new)],
    );
    addTearDown(container.dispose);
    final client = container.read(openApiConfigProvider);
    (container.read(globalDataServiceProvider.notifier) as _Session)
        .setCamera();
    expect(container.read(openApiConfigProvider), same(client));
  });

  test(
    'logout invalidates a pending refresh before it can send an API request',
    () async {
      final refreshStarted = Completer<void>();
      final refreshResult = Completer<http.StreamedResponse>();
      var protectedRequests = 0;
      await http.runWithClient(
        () async {
          final container = ProviderContainer(
            overrides: [globalDataServiceProvider.overrideWith(_Session.new)],
          );
          addTearDown(container.dispose);
          final client = container.read(openApiConfigProvider);
          final request = client.client.get(
            Uri.parse('https://example.test/pins'),
          );
          final rejected = expectLater(
            request,
            throwsA(isA<http.ClientException>()),
          );
          await refreshStarted.future;
          (container.read(globalDataServiceProvider.notifier) as _Session)
              .setSession(null);
          refreshResult.complete(
            _jsonResponse({
              'accessToken': 'late',
              'refreshToken': 'first-refresh',
              'userId': 'first',
            }),
          );
          await rejected;
          expect(protectedRequests, 0);
        },
        () => _CallbackClient((request) async {
          if (request.url.path.contains('refresh')) {
            refreshStarted.complete();
            return refreshResult.future;
          }
          protectedRequests++;
          return _response(200);
        }),
      );
    },
  );

  test('refresh stores the replacement access token', () async {
    final tokenManager = AccessTokenManager(
      refreshAccessToken: () => Future<String?>.value('replacement-token'),
    );

    await tokenManager.refresh();

    expect(tokenManager.accessToken, 'replacement-token');
  });

  test('shares an in-flight refresh between concurrent callers', () async {
    final refreshStarted = Completer<void>();
    final refreshResult = Completer<String?>();
    var refreshes = 0;
    final tokenManager = AccessTokenManager(
      refreshAccessToken: () {
        refreshes++;
        refreshStarted.complete();
        return refreshResult.future;
      },
    );

    final first = tokenManager.refresh();
    final second = tokenManager.refresh();
    await refreshStarted.future;

    expect(refreshes, 1);
    refreshResult.complete('shared-token');
    await Future.wait([first, second]);

    expect(tokenManager.accessToken, 'shared-token');
  });

  test('invalid refresh credentials clear the access token', () async {
    final tokenManager = AccessTokenManager(
      initialAccessToken: 'stale-token',
      refreshAccessToken: () =>
          Future<String?>.error(ApiException(401, 'refresh token expired')),
    );

    await expectLater(
      tokenManager.refresh(force: true),
      throwsA(isA<InvalidRefreshCredentialsException>()),
    );

    expect(tokenManager.accessToken, isEmpty);
  });

  test(
    'transient refresh failures preserve the existing access token',
    () async {
      final transientFailure = ApiException(503, 'service unavailable');
      final tokenManager = AccessTokenManager(
        initialAccessToken: 'usable-token',
        refreshAccessToken: () => Future<String?>.error(transientFailure),
      );

      await expectLater(
        tokenManager.refresh(force: true),
        throwsA(same(transientFailure)),
      );

      expect(tokenManager.accessToken, 'usable-token');
    },
  );

  test('401 retry sends the replacement access token', () async {
    final requests = _RecordingClient([401, 200]);
    final now = DateTime(2026, 8, 29);
    var refreshes = 0;
    final tokenManager = AccessTokenManager(
      initialAccessToken: 'stale-token',
      lastRefreshAt: now,
      now: () => now,
      refreshAccessToken: () {
        refreshes++;
        return Future<String?>.value('replacement-token');
      },
    );
    final client = createRetryingAuthClient(
      inner: requests,
      tokenManager: tokenManager,
      rateLimitDelay: Duration.zero,
    );
    addTearDown(client.close);

    final response = await client.get(Uri.parse('https://example.test/pins'));

    expect(response.statusCode, 200);
    expect(refreshes, 1);
    expect(requests.authorizationHeaders, [
      'Bearer stale-token',
      'Bearer replacement-token',
    ]);
  });

  test('403 responses are not retried as authentication failures', () async {
    final requests = _RecordingClient([403]);
    final now = DateTime(2026, 8, 29);
    var refreshes = 0;
    final tokenManager = AccessTokenManager(
      initialAccessToken: 'usable-token',
      lastRefreshAt: now,
      now: () => now,
      refreshAccessToken: () {
        refreshes++;
        return Future<String?>.value('replacement-token');
      },
    );
    final client = createRetryingAuthClient(
      inner: requests,
      tokenManager: tokenManager,
      rateLimitDelay: Duration.zero,
    );
    addTearDown(client.close);

    final response = await client.get(Uri.parse('https://example.test/pins'));

    expect(response.statusCode, 403);
    expect(refreshes, 0);
    expect(requests.authorizationHeaders, ['Bearer usable-token']);
  });

  test(
    'the request limiter admits unrelated requests up to its bound',
    () async {
      final releaseRequests = Completer<void>();
      final twoRequestsStarted = Completer<void>();
      var startedRequests = 0;
      final inner = _CallbackClient((_) async {
        startedRequests++;
        if (startedRequests == 2) {
          twoRequestsStarted.complete();
        }
        await releaseRequests.future;
        return _response(200);
      });
      final client = RateLimitedAuthClient(
        inner: inner,
        ensureToken: () async {},
        getToken: () => '',
        maxConcurrentRequests: 2,
        rateLimitDelay: Duration.zero,
      );
      addTearDown(client.close);

      final first = client.get(Uri.parse('https://example.test/one'));
      final second = client.get(Uri.parse('https://example.test/two'));

      await twoRequestsStarted.future.timeout(const Duration(seconds: 1));
      expect(startedRequests, 2);

      releaseRequests.complete();
      await Future.wait([first, second]);
    },
  );

  test('closing configured clients closes the owned HTTP client', () {
    final inner = _RecordingClient([200]);
    final tokenManager = AccessTokenManager(
      refreshAccessToken: () => Future<String?>.value('token'),
    );
    final resources =
        OpenApiClientFactory(
          httpClientFactory: () => inner,
          rateLimitDelay: Duration.zero,
        ).create(
          basePath: 'https://example.test',
          authentication: HttpBearerAuth(),
          tokenManager: tokenManager,
        );

    resources.close();

    expect(inner.closed, isTrue);
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._statusCodes);

  final List<int> _statusCodes;
  final List<String?> authorizationHeaders = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    authorizationHeaders.add(request.headers['Authorization']);
    return _response(_statusCodes.removeAt(0));
  }

  @override
  void close() {
    closed = true;
  }
}

class _CallbackClient extends http.BaseClient {
  _CallbackClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}

http.StreamedResponse _response(int statusCode) {
  return http.StreamedResponse(Stream<List<int>>.value(const []), statusCode);
}

OpenApiClientResources _resources(
  AccessTokenManager manager,
  http.Client inner,
) {
  return OpenApiClientFactory(
    httpClientFactory: () => inner,
    rateLimitDelay: Duration.zero,
  ).create(
    basePath: 'https://example.test',
    authentication: HttpBearerAuth(),
    tokenManager: manager,
  );
}

http.StreamedResponse _jsonResponse(Map<String, Object?> payload) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(payload))),
    200,
    headers: {'content-type': 'application/json'},
  );
}

class _Session extends GlobalDataService {
  @override
  GlobalDataDto build() => const GlobalDataDto(
    userId: 'first',
    refreshToken: 'first-refresh',
    cameras: [],
  );

  void setSession(String? userId) {
    state = GlobalDataDto(
      userId: userId,
      refreshToken: userId == null ? null : '$userId-refresh',
      cameras: state.cameras,
    );
  }

  void setCamera() {
    state = state.copyWith(
      cameras: const [
        CameraDescription(
          name: 'camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ],
    );
  }
}
