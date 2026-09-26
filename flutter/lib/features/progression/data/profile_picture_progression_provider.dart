import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

final userAvatarProgressionProvider = FutureProvider.autoDispose
    .family<ProfileProgressionDto?, String>((ref, userId) async {
      if (!ref.watch(accountSessionProvider).isActive) return null;

      final session = watchSession(ref);
      final result = await ref
          .watch(batchReadCoalescerProvider)
          .readKey(BatchReadKey(BatchReadKind.userProgression, userId));
      if (!isCurrentSession(ref, session)) return null;
      return result.progression;
    });

final groupAvatarProgressionProvider = FutureProvider.autoDispose
    .family<ProfileProgressionDto?, String>((ref, groupId) async {
      if (!ref.watch(accountSessionProvider).isActive) return null;
      ref.watch(
        userGroupServiceProvider.select(
          (groups) => groups.value?.any((group) => group.groupId == groupId),
        ),
      );

      final session = watchSession(ref);
      final result = await ref
          .watch(batchReadCoalescerProvider)
          .readKey(BatchReadKey(BatchReadKind.groupProgression, groupId));
      if (!isCurrentSession(ref, session)) return null;
      return result.progression;
    });
