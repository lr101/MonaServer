import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

void main() {
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
