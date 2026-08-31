import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_join_action_button.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/pop_up_menu_leave.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserGroupOverview extends ConsumerWidget {
  const UserGroupOverview({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupServiceProvider(groupId));
    final detailsReady = ref.watch(groupDetailsReadyProvider(groupId));
    final isInUserGroup = ref.watch(
      userGroupServiceProvider.select(
        (e) => e.value?.any((t) => t.groupId == groupAsync.value?.groupId),
      ),
    );
    return groupAsync.when(
      data: (data) {
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        } else {
          return detailsReady.when(
            data: (_) {
              if (isInUserGroup == true) {
                return GroupOverview(
                  groupId: groupId,
                  actions: [PopUpMenuLeave(groupDto: data)],
                );
              } else if (data.visibility == 0) {
                return GroupOverview(
                  groupId: data.groupId,
                  floatingActionButton: GroupJoinActionButton(
                    groupDto: data,
                    key: Key("group-join-$groupId"),
                  ),
                );
              } else {
                return CustomAvatarScaffold(
                  floatingActionButton: GroupJoinActionButton(
                    groupDto: data,
                    key: Key("no-user-group-join-$groupId"),
                  ),
                  avatar: ref.watch(groupProfilePictureByIdProvider(groupId)),
                  title: Text(
                    data.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  body: const Center(child: Icon(Icons.lock)),
                );
              }
            },
            error: (error, stackTrace) =>
                const Center(child: Icon(Icons.error)),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        }
      },
      error: (error, stackTrace) => const Center(child: Icon(Icons.error)),
      loading: () => const SizedBox.shrink(),
    );
  }
}
