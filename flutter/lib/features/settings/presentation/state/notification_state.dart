import 'package:buff_lisa/data/service/init_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_state.g.dart';

@riverpod
class NotificationState extends _$NotificationState {
  @override
  Future<bool> build() async {
    return await Permission.notification.isGranted;
  }

  Future<void> updatePermission(bool isGranted) async {
    if (isGranted) {
      await ref.watch(initServiceProvider.notifier).requestPermission();
      state = const AsyncData(true);
    } else {
      await ref.watch(initServiceProvider.notifier).revokePermission();
      state = const AsyncData(false);
    }
  }



}
