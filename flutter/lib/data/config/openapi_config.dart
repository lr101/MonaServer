import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
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

  String _accessToken;
  DateTime? _lastRefreshAt;

  String get accessToken => _accessToken;

  bool get needsRefresh {
    final lastRefreshAt = _lastRefreshAt;
    return lastRefreshAt == null ||
        _now().difference(lastRefreshAt) > _refreshInterval;
  }

  Future<void> refresh({bool force = false}) async {
    final accessTokenBeforeWait = _accessToken;
    if (!force && !needsRefresh) {
      return;
    }

    await _mutex.protect(() async {
      if (!force && !needsRefresh) {
        return;
      }
      if (force && _accessToken != accessTokenBeforeWait) {
        return;
      }

      try {
        final accessToken = await _refreshAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          _clearCredentials();
          throw const InvalidRefreshCredentialsException();
        }
        _accessToken = accessToken;
        _lastRefreshAt = _now();
      } on ApiException catch (error, stackTrace) {
        if (error.code == 401 || error.code == 403) {
          _clearCredentials();
          Error.throwWithStackTrace(
            const InvalidRefreshCredentialsException(),
            stackTrace,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  void _clearCredentials() {
    _accessToken = '';
    _lastRefreshAt = null;
  }
}

@Riverpod(keepAlive: true)
class OpenApiConfig extends _$OpenApiConfig {
  final OpenApiClientFactory _clientFactory = OpenApiClientFactory();
  AccessTokenManager? _tokenManager;

  OpenApiClientResources? _resources;

  @override
  ApiClient build() {
    final data = ref.watch(globalDataServiceProvider);
    _resources?.close();

    final tokenManager = AccessTokenManager(
      refreshAccessToken: () => _refreshAccessToken(data),
    );
    _tokenManager = tokenManager;
    final authentication = HttpBearerAuth();
    authentication.accessToken = () => tokenManager.accessToken;
    final resources = _clientFactory.create(
      basePath: data.host,
      authentication: authentication,
      tokenManager: tokenManager,
      ensureToken: () => _ensureTokenExists(tokenManager),
    );
    _resources = resources;
    ref.onDispose(_disposeResources);
    return resources.apiClient;
  }

  Future<void> _ensureTokenExists(AccessTokenManager tokenManager) async {
    if (tokenManager.accessToken.isEmpty || tokenManager.needsRefresh) {
      await tokenManager.refresh();
    }
  }

  Future<void> provideAccessToken({bool force = false}) async {
    final tokenManager = _tokenManager;
    if (tokenManager == null) return;
    final refreshToken = ref.read(globalDataServiceProvider).refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }
    await tokenManager.refresh(force: force);
  }

  Future<String?> _refreshAccessToken(GlobalDataDto data) async {
    final refreshToken = data.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final refreshApiClient = ApiClient(basePath: data.host);
    final generatedClient = refreshApiClient.client;
    final refreshHttpClient = http.Client();
    refreshApiClient.client = refreshHttpClient;
    generatedClient.close();

    try {
      final response = await AuthApi(refreshApiClient).refreshToken(
        refreshTokenRequestDto: RefreshTokenRequestDto(
          refreshToken: refreshToken,
          userId: data.userId,
        ),
      );
      return response?.accessToken;
    } finally {
      refreshHttpClient.close();
    }
  }

  void _disposeResources() {
    _resources?.close();
    _resources = null;
  }
}

/// Builds the OpenAPI HTTP stack and owns the client it creates.
class OpenApiClientFactory {
  OpenApiClientFactory({
    HttpClientFactory? httpClientFactory,
    this.maxConcurrentRequests = 4,
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
    return OpenApiClientResources(apiClient);
  }
}

/// Closes the complete HTTP stack created for an [ApiClient].
class OpenApiClientResources {
  OpenApiClientResources(this.apiClient);

  final ApiClient apiClient;
  var _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    apiClient.client.close();
  }
}

http.Client createRetryingAuthClient({
  required http.Client inner,
  required AccessTokenManager tokenManager,
  Future<void> Function()? ensureToken,
  int maxConcurrentRequests = 4,
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
    when: (response) =>
        response.statusCode == 401 || response.statusCode == 403,
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
    int maxConcurrentRequests = 4,
    this.rateLimitDelay = const Duration(milliseconds: 50),
  }) : _requestLimiter = _RequestLimiter(maxConcurrentRequests);

  final http.Client inner;
  final Future<void> Function() ensureToken;
  final String Function() getToken;
  final Duration rateLimitDelay;
  final _RequestLimiter _requestLimiter;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _requestLimiter.run(() async {
      await ensureToken();

      final accessToken = getToken();
      if (accessToken.isEmpty) {
        request.headers.remove('Authorization');
      } else {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await inner.send(request);
      await Future<void>.delayed(rateLimitDelay);
      return response;
    });
  }

  @override
  void close() {
    _requestLimiter.close();
    inner.close();
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
  var _closed = false;

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_closed) {
      return Future<void>.error(StateError('HTTP client is closed'));
    }
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

  void close() {
    if (_closed) return;
    _closed = true;
    while (_waitingRequests.isNotEmpty) {
      _waitingRequests.removeFirst().completeError(
        StateError('HTTP client is closed'),
      );
    }
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
