import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/features/group_edit/presentation/group_edit.dart';
import 'package:buff_lisa/features/group_overview/presentation/group_pin_settings.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_action_button.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_invite_share_button.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Group information and actions, reached from the profile's settings button.
class GroupSettingsPage extends ConsumerWidget {
  const GroupSettingsPage({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(groupDetailsProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(groupDetailsProvider(groupId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
        data: (details) {
          final group = details.group;
          if (group == null) {
            return const Center(child: Text('Group unavailable.'));
          }
          final member = group.userIsMember;
          if (!member) {
            return const Center(
              child: Text('Join this group to access its settings.'),
            );
          }
          final isAdmin = ref.watch(userIdProvider) == group.groupAdmin;
          if (isAdmin) {
            return GroupEdit(
              key: ValueKey('settings-edit-$groupId'),
              groupid: groupId,
              group: group,
              embedded: true,
              footerItems: [
                GroupPinSettings(group: group),
                if (group.bestSeason != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: SeasonTile(bestSeason: group.bestSeason!),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (group.inviteUrl != null) ...[
                        GroupInviteShareButton(groupDto: group, expanded: true),
                        const Divider(height: 1),
                      ],
                      GroupActionButton(
                        group: group,
                        action: GroupAction.report,
                        expanded: true,
                      ),
                      const Divider(height: 1),
                      GroupActionButton(
                        group: group,
                        action: GroupAction.leave,
                        expanded: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (group.description?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  group.description!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                              if (group.link?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.open_in_new),
                                  title: Text(group.link!),
                                  onTap: () => clickedOnLink(group.link),
                                ),
                              ],
                              if (group.bestSeason != null)
                                SeasonTile(bestSeason: group.bestSeason!),
                            ],
                          ),
                        ),
                      ),
                      if (member) ...[
                        const SizedBox(height: 16),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              if (group.inviteUrl != null)
                                GroupInviteShareButton(
                                  groupDto: group,
                                  expanded: true,
                                ),
                              if (group.inviteUrl != null)
                                const Divider(height: 1),
                              GroupActionButton(
                                group: group,
                                action: GroupAction.report,
                                expanded: true,
                              ),
                              const Divider(height: 1),
                              GroupActionButton(
                                group: group,
                                action: GroupAction.leave,
                                expanded: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
