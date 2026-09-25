import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupAchievementsPanel extends ConsumerStatefulWidget {
  const GroupAchievementsPanel({
    super.key,
    required this.groupId,
    required this.group,
  });

  final String groupId;
  final GroupEntity? group;

  @override
  ConsumerState<GroupAchievementsPanel> createState() =>
      _GroupAchievementsPanelState();
}

class _GroupAchievementsPanelState
    extends ConsumerState<GroupAchievementsPanel> {
  int? _claimingAchievementId;
  int? _celebratingAchievementId;
  bool _updatingPinStyle = false;

  @override
  Widget build(BuildContext context) {
    final achievements = ref.watch(groupAchievementsProvider(widget.groupId));
    return achievements.when(
      data: (items) => items == null || items.isEmpty
          ? const SizedBox.shrink()
          : GroupAchievementsCard(
              achievements: items,
              group: widget.group,
              currentUserId: ref.watch(userIdProvider),
              claimingAchievementId: _claimingAchievementId,
              celebratingAchievementId: _celebratingAchievementId,
              updatingPinStyle: _updatingPinStyle,
              onClaimAchievement: _claimAchievement,
              onPinStyleSelected: _selectPinStyle,
            ),
      loading: () => const _GroupAchievementsLoadingCard(),
      error: (error, stackTrace) => _GroupAchievementsErrorCard(
        onRetry: () =>
            ref.invalidate(groupAchievementsProvider(widget.groupId)),
      ),
    );
  }

  Future<void> _claimAchievement(int achievementId) async {
    setState(() => _claimingAchievementId = achievementId);
    try {
      await ref
          .read(groupApiProvider)
          .claimGroupAchievement(widget.groupId, achievementId);
      if (!mounted) return;
      ref.invalidate(groupAchievementsProvider(widget.groupId));
      setState(() => _celebratingAchievementId = achievementId);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Group reward unlocked'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not claim this group reward. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingAchievementId = null);
    }
  }

  Future<String?> _selectPinStyle(String style) async {
    final group = widget.group;
    if (group == null) return 'Group details are unavailable';
    setState(() => _updatingPinStyle = true);
    try {
      final error = await ref
          .read(userGroupServiceProvider.notifier)
          .updateGroup(
            group.copyWith(pinStyle: style).toUpdateGroupDto(null),
            widget.groupId,
          );
      if (error == null && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('${_styleName(style)} frame selected for group pins'),
          ),
        );
      } else if (error != null && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not update pin appearance: $error'),
          ),
        );
      }
      return error;
    } finally {
      if (mounted) setState(() => _updatingPinStyle = false);
    }
  }
}

class _GroupAchievementsLoadingCard extends StatelessWidget {
  const _GroupAchievementsLoadingCard();

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group achievements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    ),
  );
}

class _GroupAchievementsErrorCard extends StatelessWidget {
  const _GroupAchievementsErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      title: const Text('Group achievements unavailable'),
      trailing: IconButton(
        tooltip: 'Retry loading group achievements',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: onRetry,
      ),
    ),
  );
}

String _styleName(String style) => switch (style) {
  'moss' => 'Moss',
  'sunset' => 'Sunset',
  'aurora' => 'Aurora',
  _ => 'Classic',
};
