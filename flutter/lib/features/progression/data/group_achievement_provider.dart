import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_achievement_provider.g.dart';

@riverpod
Future<List<GroupAchievementsDtoInner>?> groupAchievements(
  Ref ref,
  String groupId,
) async {
  if (!ref.watch(accountSessionProvider).isActive) return null;

  final session = watchSession(ref);
  final achievements = await ref
      .watch(groupApiProvider)
      .getGroupAchievements(groupId);
  if (!isCurrentSession(ref, session)) return null;
  return achievements;
}
