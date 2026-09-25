import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_xp_provider.g.dart';

@riverpod
Future<UserXpDto?> userXp(Ref ref, String userId) async {
  if (!ref.watch(accountSessionProvider).isActive) return null;

  final session = watchSession(ref);
  if (session.userId != userId) return null;

  final xp = await ref.watch(userApiProvider).getUserXp(userId);
  if (!isCurrentSession(ref, session)) return null;
  return xp;
}
