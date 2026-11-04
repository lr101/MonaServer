import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_join_action_button.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserGroupOverview extends ConsumerWidget {
  const UserGroupOverview({super.key, required this.groupId, this.inviteUrl});

  final String groupId;
  final String? inviteUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(groupDetailsProvider(groupId));
    return detailsAsync.when(
      data: (details) {
        final group = details.group;
        if (group == null) {
          return const Center(child: Icon(Icons.error));
        } else if (group.userIsMember) {
          return GroupOverview(groupId: groupId, details: details);
        } else if (group.visibility == 0) {
          return GroupOverview(
            groupId: group.groupId,
            details: details,
            floatingActionButton: GroupJoinActionButton(
              groupDto: group,
              inviteUrl: inviteUrl,
              key: Key("group-join-$groupId"),
            ),
          );
        } else {
          return CustomAvatarScaffold(
            toolbarHeight: groupTitleToolbarHeight(context, group.name),
            floatingActionButton: GroupJoinActionButton(
              groupDto: group,
              inviteUrl: inviteUrl,
              key: Key("no-user-group-join-$groupId"),
            ),
            remoteAvatar: details.profileImage,
            title: Text(
              group.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                height: 1.15,
              ),
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
