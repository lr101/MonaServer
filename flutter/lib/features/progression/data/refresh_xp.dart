import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/xp_gain_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A missing XP endpoint must never prevent saving a pin or claiming a reward.
/// Read once before mutations to establish a baseline, then after confirmation.
Future<void> readXpBestEffort(
  Ref ref,
  String userId, {
  String? groupId,
  bool refresh = false,
}) async {
  final gains = ref.read(xpGainsProvider.notifier);
  final readUserXp = refresh || !gains.hasBaseline('user:$userId');
  final readGroupXp =
      groupId != null && (refresh || !gains.hasBaseline('group:$groupId'));

  Future<void> readUser() async {
    if (!readUserXp) return;
    try {
      if (refresh) ref.invalidate(userXpProvider(userId));
      await ref
          .read(userXpProvider(userId).future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* XP will recover on the next refresh. */
    }
  }

  Future<void> readGroup(String id) async {
    if (!readGroupXp) return;
    try {
      if (refresh) ref.invalidate(groupProgressionProvider(id));
      await ref
          .read(groupProgressionProvider(id).future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      /* XP will recover on the next refresh. */
    }
  }

  await Future.wait([
    readUser(),
    if (readGroupXp && groupId != null) readGroup(groupId),
  ]);
}
