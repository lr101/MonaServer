import 'package:buff_lisa/data/service/group_details_service.dart';
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
    final detailsAsync = ref.watch(groupDetailsProvider(groupId));
    return detailsAsync.when(
      data: (details) {
        final group = details.group;
        if (group == null) {
          return const Center(child: Text('Group not found'));
        } else if (group.userIsMember) {
          return GroupOverview(
            groupId: groupId,
            details: details,
            actions: [PopUpMenuLeave(groupDto: group)],
          );
        } else if (group.visibility == 0) {
          return GroupOverview(
            groupId: group.groupId,
            details: details,
            floatingActionButton: GroupJoinActionButton(
              groupDto: group,
              key: Key("group-join-$groupId"),
            ),
          );
        } else {
          return CustomAvatarScaffold(
            floatingActionButton: GroupJoinActionButton(
              groupDto: group,
              key: Key("no-user-group-join-$groupId"),
            ),
            avatar: details.profileImage,
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            body: const Center(child: Icon(Icons.lock)),
          );
        }
      },
      error: (error, stackTrace) => const Center(child: Icon(Icons.error)),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
