import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'global_data_service.g.dart';

@Riverpod(keepAlive: true)
class GlobalDataService extends _$GlobalDataService {
  bool _cleanupPendingInMemory = false;

  @override
  GlobalDataDto build() => ref.watch(globalDataOnceProvider);

  Future<void> logout({bool clearStateOnFailure = false}) async {
    try {
      await ref
          .read(accountDataCleanupProvider)
          .clearForLogout(
            continueWithSessionOnCacheFailure: clearStateOnFailure,
          );
    } catch (error, stackTrace) {
      final markerSaved = await _markCleanupPending();
      if (!markerSaved) {
        debugPrint('Unable to persist the account cleanup marker.');
      }
      if (clearStateOnFailure) {
        _clearSessionState();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!await _clearCleanupPending()) {
      debugPrint('Unable to clear the account cleanup marker.');
    }
    _clearSessionState();
  }

  Future<String?> prepareForNewSession() async {
    if (!await _hasCleanupPending()) {
      return null;
    }

    try {
      await ref.read(accountDataCleanupProvider).clearForLogout();
      if (!await _clearCleanupPending()) {
        return 'Unable to clear data from the previous account. Please try again.';
      }
      return null;
    } catch (_) {
      return 'Unable to clear data from the previous account. Please try again.';
    }
  }

  Future<bool> _markCleanupPending() async {
    _cleanupPendingInMemory = true;
    var persisted = false;
    try {
      persisted = await ref
          .read(sharedPreferencesProvider)
          .setBool(GlobalDataRepository.accountCleanupPendingKey, true);
    } catch (_) {
      // Try the secure store if SharedPreferences is unavailable.
    }
    if (!persisted) {
      try {
        await ref
            .read(secureStorageProvider)
            .write(
              key: GlobalDataRepository.accountCleanupPendingStorageKey,
              value: 'true',
            );
        persisted = true;
      } catch (_) {
        // Keep the in-memory fail-closed marker if both stores are unavailable.
      }
    }
    return persisted;
  }

  Future<bool> _clearCleanupPending() async {
    var cleared = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final removed = await prefs.remove(
        GlobalDataRepository.accountCleanupPendingKey,
      );
      if (!removed &&
          prefs.containsKey(GlobalDataRepository.accountCleanupPendingKey)) {
        cleared = false;
      }
    } catch (_) {
      cleared = false;
    }

    try {
      final storage = ref.read(secureStorageProvider);
      final marker = await storage.read(
        key: GlobalDataRepository.accountCleanupPendingStorageKey,
      );
      if (marker != null) {
        await storage.delete(
          key: GlobalDataRepository.accountCleanupPendingStorageKey,
        );
        if (await storage.read(
              key: GlobalDataRepository.accountCleanupPendingStorageKey,
            ) !=
            null) {
          cleared = false;
        }
      }
    } catch (_) {
      cleared = false;
    }

    _cleanupPendingInMemory = !cleared;
    return cleared;
  }

  Future<bool> _hasCleanupPending() async {
    if (_cleanupPendingInMemory) return true;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(GlobalDataRepository.accountCleanupPendingKey) == true) {
      _cleanupPendingInMemory = true;
      return true;
    }

    try {
      final marker = await ref
          .read(secureStorageProvider)
          .read(key: GlobalDataRepository.accountCleanupPendingStorageKey);
      _cleanupPendingInMemory = marker == 'true';
      return _cleanupPendingInMemory;
    } catch (_) {
      // If the marker cannot be read, fail closed until storage recovers.
      _cleanupPendingInMemory = true;
      return true;
    }
  }

  void _clearSessionState() {
    ref.invalidate(openApiConfigProvider);
    ref.invalidate(lastSeenProvider);
    ref.invalidate(hiddenUserServiceProvider);
    ref.invalidate(hiddenPostsServiceProvider);
    state = GlobalDataDto(
      userId: null,
      refreshToken: null,
      cameras: state.cameras,
    );
  }

  Future<void> updateData(
    TokenResponseDto refreshToken,
    String username,
  ) async {
    ref.invalidate(openApiConfigProvider);
    ref.read(accountDataSessionGuardProvider).beginSession();
    state = state.copyWith(
      refreshToken: refreshToken.refreshToken,
      userId: refreshToken.userId,
    );
    await ref
        .read(globalDataRepositoryProvider)
        .login(username, refreshToken.userId, refreshToken.refreshToken);
  }

  Future<void> refreshCameraList() async {
    final cameras = await availableCameras();
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
    ref.invalidate(openApiConfigProvider);
    final authApi = ref.read(authApiProvider);
    final global = ref.read(globalDataServiceProvider.notifier);
    try {
      final response = await authApi.userLogin(
        UserLoginRequest(username: name, password: password),
      );
      if (response != null) {
        final cleanupError = await global.prepareForNewSession();
        if (cleanupError != null) return cleanupError;
        await global.updateData(response, name);
        return null;
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
    ref.invalidate(openApiConfigProvider);
    final authApi = ref.read(authApiProvider);
    final global = ref.read(globalDataServiceProvider.notifier);
    try {
      final cleanupError = await global.prepareForNewSession();
      if (cleanupError != null) return cleanupError;
      final request = UserRequestDto(
        name: username,
        password: password,
        email: email,
      );
      final response = await authApi.createUser(request);
      if (response != null) {
        await global.updateData(response, username);
        return null;
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
    try {
      await userApi.deleteUser(userId, body: code);
    } on ApiException catch (e) {
      if (kDebugMode) print('Error deleting account: $e');
      return e.message;
    }
    try {
      await global.logout(clearStateOnFailure: true);
      return null;
    } catch (e) {
      if (kDebugMode) print('Error cleaning up deleted account: $e');
      return 'Your account was deleted, but local cleanup failed. Please restart the app.';
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

  Future<void> setLastSeenNow() async {
    state = DateTime.now();
    await ref
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
