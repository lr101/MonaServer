import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:mutex/mutex.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'openapi_config.g.dart';

typedef RefreshAccessToken = Future<String?> Function();
typedef HttpClientFactory = http.Client Function();

/// Signals that a refresh token is no longer accepted by the server.
class InvalidRefreshCredentialsException implements Exception {
  const InvalidRefreshCredentialsException();

  @override
  String toString() => 'Invalid refresh credentials';
}

/// Owns the in-memory access token and serializes refresh attempts.
class AccessTokenManager {
  factory AccessTokenManager({
    required RefreshAccessToken refreshAccessToken,
    String initialAccessToken = '',
    DateTime? lastRefreshAt,
    DateTime Function()? now,
  }) {
    return AccessTokenManager._(
      refreshAccessToken,
      initialAccessToken,
      lastRefreshAt,
      now ?? DateTime.now,
    );
  }

  AccessTokenManager._(
    this._refreshAccessToken,
    this._accessToken,
    this._lastRefreshAt,
    this._now,
  );

  static const _refreshInterval = Duration(minutes: 1);

  final RefreshAccessToken _refreshAccessToken;
  final DateTime Function() _now;
  final Mutex _mutex = Mutex();
  final _ClientLifetime _lifetime = _ClientLifetime();

  String _accessToken;
  DateTime? _lastRefreshAt;

  String get accessToken => _accessToken;

  bool get needsRefresh {
    final lastRefreshAt = _lastRefreshAt;
    return lastRefreshAt == null ||
        _now().difference(lastRefreshAt) > _refreshInterval;
  }

  Future<void> refresh({bool force = false}) async {
    _lifetime.checkOpen();
    final accessTokenBeforeWait = _accessToken;
    if (!force && !needsRefresh) {
      return;
    }

    await _lifetime.guard(
      () => _mutex.protect(() async {
        _lifetime.checkOpen();
        if (!force && !needsRefresh) {
          return;
        }
        if (force && _accessToken != accessTokenBeforeWait) {
          return;
        }

        try {
          final accessToken = await _refreshAccessToken();
          _lifetime.checkOpen();
          if (accessToken == null || accessToken.isEmpty) {
            _clearCredentials();
            throw const InvalidRefreshCredentialsException();
          }
          _accessToken = accessToken;
          _lastRefreshAt = _now();
        } on ApiException catch (error, stackTrace) {
          _lifetime.checkOpen();
          if (error.code == 401 || error.code == 403) {
            _clearCredentials();
            Error.throwWithStackTrace(
              const InvalidRefreshCredentialsException(),
              stackTrace,
            );
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      }),
    );
  }

  void dispose() {
    _lifetime.close();
    _clearCredentials();
  }

  void _clearCredentials() {
    _accessToken = '';
    _lastRefreshAt = null;
  }
}

@Riverpod(keepAlive: true)
class OpenApiConfig extends _$OpenApiConfig {
  AccessTokenManager? _tokenManager;

  @override
  ApiClient build() {
    final session = ref.watch(
      globalDataServiceProvider.select(
        (data) => (
          host: data.host,
          userId: data.userId,
          refreshToken: data.refreshToken,
        ),
      ),
    );
    // Each build captures one session, including the refresh transport.
    final refreshApiClient = ApiClient(basePath: session.host);
    final tokenManager = AccessTokenManager(
      refreshAccessToken: () async {
        final refreshToken = session.refreshToken;
        if (refreshToken == null || refreshToken.isEmpty) return null;
        final response = await AuthApi(refreshApiClient).refreshToken(
          refreshTokenRequestDto: RefreshTokenRequestDto(
            refreshToken: refreshToken,
            userId: session.userId,
          ),
        );
        return response?.accessToken;
      },
    );
    _tokenManager = tokenManager;
    final authentication = HttpBearerAuth()
      ..accessToken = () => tokenManager.accessToken;
    final resources = OpenApiClientFactory().create(
      basePath: session.host,
      authentication: authentication,
      tokenManager: tokenManager,
      ensureToken: () async {
        if (session.refreshToken?.isNotEmpty == true) {
          await tokenManager.refresh();
        }
      },
    );
    ref.onDispose(() {
      resources.close();
      refreshApiClient.client.close();
    });
    return resources.apiClient;
  }

  Future<void> provideAccessToken({bool force = false}) async {
    await _tokenManager?.refresh(force: force);
  }
}

/// Builds the OpenAPI HTTP stack and owns the client it creates.
class OpenApiClientFactory {
  OpenApiClientFactory({
    HttpClientFactory? httpClientFactory,
    this.maxConcurrentRequests = 1,
    this.rateLimitDelay = const Duration(milliseconds: 50),
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new;

  final HttpClientFactory _httpClientFactory;
  final int maxConcurrentRequests;
  final Duration rateLimitDelay;

  OpenApiClientResources create({
    required String basePath,
    required HttpBearerAuth authentication,
    required AccessTokenManager tokenManager,
    Future<void> Function()? ensureToken,
  }) {
    final apiClient = ApiClient(
      basePath: basePath,
      authentication: authentication,
    );
    final generatedClient = apiClient.client;
    final authenticatedClient = createRetryingAuthClient(
      inner: _httpClientFactory(),
      tokenManager: tokenManager,
      ensureToken: ensureToken,
      maxConcurrentRequests: maxConcurrentRequests,
      rateLimitDelay: rateLimitDelay,
    );
    apiClient.client = authenticatedClient;
    generatedClient.close();
    return OpenApiClientResources(apiClient, tokenManager);
  }
}

/// Closes the complete HTTP stack created for an [ApiClient].
class OpenApiClientResources {
  OpenApiClientResources(this.apiClient, this._tokenManager);

  final ApiClient apiClient;
  final AccessTokenManager _tokenManager;

  void close() {
    _tokenManager.dispose();
    apiClient.client.close();
  }
}

http.Client createRetryingAuthClient({
  required http.Client inner,
  required AccessTokenManager tokenManager,
  Future<void> Function()? ensureToken,
  int maxConcurrentRequests = 1,
  Duration rateLimitDelay = const Duration(milliseconds: 50),
}) {
  final interceptorClient = RateLimitedAuthClient(
    inner: inner,
    ensureToken: ensureToken ?? tokenManager.refresh,
    getToken: () => tokenManager.accessToken,
    maxConcurrentRequests: maxConcurrentRequests,
    rateLimitDelay: rateLimitDelay,
  );
  return RetryClient(
    interceptorClient,
    delay: (_) => Duration.zero,
    retries: 1,
    when: (response) => response.statusCode == 401,
    onRetry: (request, response, retryCount) async {
      if (retryCount != 0 || response == null) {
        return;
      }
      await tokenManager.refresh(force: true);
      final accessToken = tokenManager.accessToken;
      if (accessToken.isEmpty) {
        request.headers.remove('Authorization');
      } else {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
    },
  );
}

/// Adds authentication and a bounded concurrency limit to API requests.
class RateLimitedAuthClient extends http.BaseClient {
  RateLimitedAuthClient({
    required this.inner,
    required this.ensureToken,
    required this.getToken,
    int maxConcurrentRequests = 1,
    this.rateLimitDelay = const Duration(milliseconds: 50),
  }) : _requestLimiter = _RequestLimiter(maxConcurrentRequests);

  final http.Client inner;
  final Future<void> Function() ensureToken;
  final String Function() getToken;
  final Duration rateLimitDelay;
  final _RequestLimiter _requestLimiter;
  final _ClientLifetime _lifetime = _ClientLifetime();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _lifetime.guard(
      () => _requestLimiter.run(() async {
        _lifetime.checkOpen();
        await ensureToken();
        _lifetime.checkOpen();

        final accessToken = getToken();
        if (accessToken.isEmpty) {
          request.headers.remove('Authorization');
        } else {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }

        final response = await inner.send(request);
        try {
          await Future<void>.delayed(rateLimitDelay);
          _lifetime.checkOpen();
        } catch (_) {
          await response.stream.listen(null).cancel();
          rethrow;
        }
        return http.StreamedResponse(
          _lifetime.bind(response.stream),
          response.statusCode,
          contentLength: response.contentLength,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }),
    );
  }

  @override
  void close() {
    if (_lifetime.isClosed) return;
    _lifetime.close();
    inner.close();
  }
}

/// Fences asynchronous work and response streams when their owner is disposed.
class _ClientLifetime {
  final _closed = StreamController<void>.broadcast(sync: true);
  bool isClosed = false;

  void checkOpen() {
    if (isClosed) throw http.ClientException('HTTP session is closed');
  }

  void close() {
    if (isClosed) return;
    isClosed = true;
    _closed.add(null);
    unawaited(_closed.close());
  }

  Future<T> guard<T>(Future<T> Function() action) async {
    checkOpen();
    final result = Completer<T>();
    final subscription = _closed.stream.listen((_) {
      if (!result.isCompleted) {
        result.completeError(http.ClientException('HTTP session is closed'));
      }
    });
    unawaited(
      Future<T>.sync(action).then(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      await subscription.cancel();
    }
  }

  Stream<T> bind<T>(Stream<T> source) {
    late StreamController<T> controller;
    StreamSubscription<T>? input;
    StreamSubscription<void>? closure;
    var deliveredError = false;
    controller = StreamController<T>(
      onListen: () {
        input = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            unawaited(closure?.cancel());
            unawaited(controller.close());
          },
        );
        void stop() {
          controller.addError(http.ClientException('HTTP session is closed'));
          unawaited(input?.cancel());
          unawaited(controller.close());
        }

        if (isClosed) {
          stop();
        } else {
          closure = _closed.stream.listen((_) => stop());
        }
      },
      onPause: () => input?.pause(),
      onResume: () => input?.resume(),
      onCancel: () async {
        await input?.cancel();
        await closure?.cancel();
      },
    );
    // Check at delivery, including completion: the source can finish before
    // buffered events reach the consumer and before the session is closed.
    return controller.stream.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) {
          if (!isClosed) sink.add(data);
        },
        handleError: (Object error, StackTrace stack, sink) {
          deliveredError = true;
          sink.addError(error, stack);
        },
        handleDone: (sink) {
          if (isClosed && !deliveredError) {
            sink.addError(http.ClientException('HTTP session is closed'));
          }
          sink.close();
        },
      ),
    );
  }
}

class _RequestLimiter {
  _RequestLimiter(this._maximumConcurrentRequests) {
    if (_maximumConcurrentRequests <= 0) {
      throw RangeError.range(
        _maximumConcurrentRequests,
        1,
        null,
        'maxConcurrentRequests',
      );
    }
  }

  final int _maximumConcurrentRequests;
  final Queue<Completer<void>> _waitingRequests = Queue<Completer<void>>();
  var _activeRequests = 0;

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_activeRequests < _maximumConcurrentRequests) {
      _activeRequests++;
      return Future<void>.value();
    }
    final request = Completer<void>();
    _waitingRequests.add(request);
    return request.future;
  }

  void _release() {
    if (_waitingRequests.isEmpty) {
      _activeRequests--;
      return;
    }
    _waitingRequests.removeFirst().complete();
  }
}

@Riverpod(keepAlive: true)
PinsApi pinApi(Ref ref) => PinsApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
GroupsApi groupApi(Ref ref) => GroupsApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
UsersApi userApi(Ref ref) => UsersApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) => AuthApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
MembersApi memberApi(Ref ref) => MembersApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
ReportApi reportApi(Ref ref) => ReportApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
LikesApi likeApi(Ref ref) => LikesApi(ref.watch(openApiConfigProvider));

@Riverpod(keepAlive: true)
RankingApi rankingApi(Ref ref) => RankingApi(ref.watch(openApiConfigProvider));
