import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_xp_provider.g.dart';

@riverpod
Future<GroupProgressionDto?> groupProgression(Ref ref, String groupId) async {
  if (!ref.watch(accountSessionProvider).isActive) return null;

  final session = watchSession(ref);
  final progression = await ref
      .watch(groupApiProvider)
      .getGroupProgression(groupId);
  if (!isCurrentSession(ref, session)) return null;
  return progression;
}
