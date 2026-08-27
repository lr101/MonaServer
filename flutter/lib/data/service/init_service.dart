import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'init_service.g.dart';

@riverpod
class InitService extends _$InitService {
  @override
  Future<bool> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isNotificationEnabled = prefs.getBool(GlobalDataRepository.isNotificationEnabledKey);
    if (isNotificationEnabled != false) {
      return await requestPermission();
    }
    return false;
  }

  Future<bool> requestPermission() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      prefs.setBool(GlobalDataRepository.isNotificationEnabledKey, true);
      final userId = ref.watch(userIdProvider);
      final userApi = ref.watch(userApiProvider);
      try {
        await FirebaseMessaging.instance.subscribeToTopic("info");
        final fcmToken = await FirebaseMessaging.instance.getToken();
        await userApi.updateUser(
            userId, UserUpdateDto(messagingToken: fcmToken));
        if (kDebugMode) print('messagingToken updated: $fcmToken');
        return true;
      } catch (e) {
        if (kDebugMode) print('Error updating messagingToken: $e');
      }
      return false;
    } else {
      prefs.setBool(GlobalDataRepository.isNotificationEnabledKey, false);
      return false;
    }
  }

  Future<void> revokePermission() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
        alert: false,
        sound: false
    );
    prefs.setBool(GlobalDataRepository.isNotificationEnabledKey, false);
    await FirebaseMessaging.instance.unsubscribeFromTopic("info");
  }
}
