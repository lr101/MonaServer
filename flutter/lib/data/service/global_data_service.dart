import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/account_cleanup_service.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'global_data_service.g.dart';

@Riverpod(keepAlive: true)
class GlobalDataService extends _$GlobalDataService {
  @override
  GlobalDataDto build() {
    final data = ref.watch(globalDataOnceProvider);
    storageSession = AccountSession(data.userId != null);
    ref.onDispose(() => storageSession.revoke());
    return data;
  }

  late AccountSession storageSession;

  Future<void>? _logoutFuture;
  Future<void> _credentialWrites = Future<void>.value();
  int _generation = 0;

  int get generation => _generation;
  bool _cleanupFailed = false;
  bool get cleanupRequired =>
      _cleanupFailed ||
      ref
              .read(sharedPreferencesProvider)
              .getBool(GlobalDataRepository.accountCleanupPending) ==
          true;

  Future<void> _serializeCredentials(Future<void> Function() action) {
    final result = _credentialWrites.then((_) => action());
    _credentialWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> logout() {
    return _logoutFuture ??= _logout().whenComplete(() => _logoutFuture = null);
  }

  Future<void> _logout() async {
    final repository = ref.read(globalDataRepositoryProvider);
    final cleanup = ref.read(accountCleanupProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    _cleanupFailed = true;
    _generation++;
    storageSession.revoke();
    storageSession = AccountSession(false);
    state = GlobalDataDto(
      userId: null,
      refreshToken: null,
      cameras: state.cameras,
    );
    await _serializeCredentials(() async {
      Object? markerError;
      StackTrace? markerStack;
      try {
        await GlobalDataRepository.requirePreferenceWrite(
          prefs.setBool(GlobalDataRepository.accountCleanupPending, true),
        );
      } catch (error, stack) {
        markerError = error;
        markerStack = stack;
      }
      await Future.wait([repository.logout(), cleanup.clearCaches()]);
      if (markerError != null) {
        Error.throwWithStackTrace(markerError, markerStack!);
      }
      await GlobalDataRepository.requirePreferenceWrite(
        prefs.remove(GlobalDataRepository.accountCleanupPending),
      );
    });
    _cleanupFailed = false;
    ref.invalidate(lastSeenProvider);
    ref.invalidate(hiddenUserServiceProvider);
    ref.invalidate(hiddenPostsServiceProvider);
  }

  Future<bool> updateData(
    TokenResponseDto token,
    String username, {
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _generation;
    final repository = ref.read(globalDataRepositoryProvider);
    await _logoutFuture;
    if (generation != _generation) return false;
    if (cleanupRequired) {
      throw StateError('Account cleanup must finish before login');
    }
    var accepted = false;
    await _serializeCredentials(() async {
      if (generation != _generation) return;
      final prefs = ref.read(sharedPreferencesProvider);
      _cleanupFailed = true;
      await GlobalDataRepository.requirePreferenceWrite(
        prefs.setBool(GlobalDataRepository.accountCleanupPending, true),
      );
      try {
        await repository.login(username, token.userId, token.refreshToken);
      } catch (_) {
        storageSession.revoke();
        storageSession = AccountSession(false);
        state = GlobalDataDto(
          userId: null,
          refreshToken: null,
          cameras: state.cameras,
        );
        await Future.wait([
          repository.logout(),
          ref.read(accountCleanupProvider).clearCaches(),
        ]);
        await GlobalDataRepository.requirePreferenceWrite(
          prefs.remove(GlobalDataRepository.accountCleanupPending),
        );
        _cleanupFailed = false;
        rethrow;
      }
      if (generation != _generation) return;
      await GlobalDataRepository.requirePreferenceWrite(
        prefs.remove(GlobalDataRepository.accountCleanupPending),
      );
      if (generation != _generation) return;
      _cleanupFailed = false;
      _generation++;
      accepted = true;
      storageSession.revoke();
      storageSession = AccountSession(true);
      state = state.copyWith(
        refreshToken: token.refreshToken,
        userId: token.userId,
      );
    });
    return accepted;
  }

  Future<void> refreshCameraList() async {
    final cameras = await loadAvailableCameras(isWeb: kIsWeb);
    state = state.copyWith(cameras: cameras);
  }
}

@riverpod
class AuthService extends _$AuthService {
  @override
  FutureOr<bool> build() {
    return true;
  }

  Future<String?> login(String name, String password) async {
    final authApi = ref.read(authApiProvider);
    final global = ref.read(globalDataServiceProvider.notifier);
    final generation = global.generation;
    try {
      final response = await authApi.userLogin(
        UserLoginRequest(username: name, password: password),
      );
      if (response != null) {
        if (global.generation != generation) return "Session ended";
        final accepted = await global.updateData(
          response,
          name,
          expectedGeneration: generation,
        );
        return accepted ? null : "Session ended";
      }
      return "Something unexpected happened";
    } on ApiException catch (e) {
      return e.message == null || e.message!.isEmpty
          ? "Something unexpected happened"
          : e.message;
    }
  }

  Future<bool> recover(String? name) async {
    final authApi = ref.read(authApiProvider);
    try {
      await authApi.requestPasswordRecovery(name!);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error during password recovery: $e');
      return false;
    }
  }

  Future<String?> signupNewUser(
    String username,
    String password,
    String email,
  ) async {
    final authApi = ref.read(authApiProvider);
    final global = ref.read(globalDataServiceProvider.notifier);
    final generation = global.generation;
    try {
      final request = UserRequestDto(
        name: username,
        password: password,
        email: email,
      );
      final response = await authApi.createUser(request);
      if (response != null) {
        if (global.generation != generation) return "Session ended";
        final accepted = await global.updateData(
          response,
          username,
          expectedGeneration: generation,
        );
        return accepted ? null : "Session ended";
      } else {
        return "Something unexpected happened";
      }
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> report(
    String reportedReferences,
    String reportMessage,
  ) async {
    final reportApi = ref.watch(reportApiProvider);
    final userId = ref.read(userIdProvider);
    try {
      final request = ReportDto(
        report: reportedReferences,
        userId: userId,
        message: reportMessage,
      );
      await reportApi.createReport(request);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> getDeleteCode() async {
    final authApi = ref.read(authApiProvider);
    try {
      final userId = ref.read(userIdProvider);
      final username = await ref.read(userByIdUsernameProvider(userId).future);
      await authApi.generateDeleteCode(username!);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> deleteAccount(int code) async {
    final userApi = ref.watch(userApiProvider);
    final userId = ref.read(userIdProvider);
    final global = ref.read(globalDataServiceProvider.notifier);
    final generation = global.generation;
    try {
      await userApi.deleteUser(userId, body: code);
      if (global.generation == generation) await global.logout();
      return null;
    } on ApiException catch (e) {
      if (kDebugMode) print('Error deleting account: $e');
      return e.message;
    }
  }
}

@riverpod
String userId(Ref ref) => ref.watch(globalDataServiceProvider).userId ?? "";

@riverpod
class CameraTorch extends _$CameraTorch {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(GlobalDataRepository.cameraTorch) ??
        false;
  }

  void setTorch(bool value) {
    state = value;
    ref
        .watch(sharedPreferencesProvider)
        .setBool(GlobalDataRepository.cameraTorch, value);
  }
}

@Riverpod(keepAlive: true)
class LastSeen extends _$LastSeen {
  @override
  DateTime? build(String key) {
    final lastSeen = ref.watch(sharedPreferencesProvider).getInt(key);
    if (lastSeen == null || kIsWeb) return null;
    return DateTime.fromMicrosecondsSinceEpoch(lastSeen);
  }

  void setLastSeenNow() {
    state = DateTime.now();
    ref
        .watch(sharedPreferencesProvider)
        .setInt(key, state!.microsecondsSinceEpoch);
  }

  void resetLastSeen() {
    state = null;
  }
}

@riverpod
LatLng lastKnownLocation(Ref ref) {
  final lat = ref
      .watch(sharedPreferencesProvider)
      .getDouble(GlobalDataRepository.lastKnownLat);
  final lng = ref
      .watch(sharedPreferencesProvider)
      .getDouble(GlobalDataRepository.lastKnownLong);
  if (lat == null || lng == null) return const LatLng(49.01105, 8.25190);
  return LatLng(lat, lng);
}
