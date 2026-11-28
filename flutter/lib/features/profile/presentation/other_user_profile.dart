import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/presentation/other_user_achievements_tab.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/profile/presentation/pop_up_menu_other_user.dart';
import 'package:buff_lisa/features/progression/data/public_user_progression_provider.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtherUserProfile extends ConsumerWidget {
  const OtherUserProfile({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(userByIdUsernameProvider(userId));
    final description = ref.watch(userByIdDescriptionProvider(userId));
    final bestSeason = ref.watch(userByIdBestSeasonProvider(userId));
    final selectedBatch = ref.watch(userByIdSelectedBatchProvider(userId));
    final selectedBatchColor = selectedBatch.value == null
        ? null
        : ref.watch(
            userServiceProvider(userId)
                .select((user) => user.value?.selectedBatchColor),
          );
    final progression = ref.watch(publicUserProgressionProvider(userId)).value;
    return DefaultTabController(
      length: 2,
      child: CustomAvatarScaffold(
        avatarBuilder: progression == null
            ? null
            : (avatar) => UserXpAvatarIndicator.public(
                level: progression.level,
                fraction: progression.fraction,
                avatar: avatar,
                radius: 40,
              ),
        remoteAvatar: RemoteImageReference(
          kind: RemoteImageKind.user,
          id: userId,
        ),
        title: Row(
          children: [
            Text(
              username.value ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            if (selectedBatch.value != null)
              Batch(
                batchId: selectedBatch.value!,
                fontSize: 10,
                colorOverride: selectedBatchColor,
              ),
          ],
        ),
        actions: [PopUpMenuOtherUser(userId: userId)],
        profileQuickViewBoxes: _buildQuickStats(context),
        bottom: const TabBar(
          labelPadding: EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_on_rounded, size: 17),
                  SizedBox(width: 6),
                  Text('Pins'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Achievements'),
                ],
              ),
            ),
          ],
        ),
        boxes: [
          if (description.value != null && description.value!.trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  description.value!.trim(),
                  softWrap: true,
                  maxLines: 10,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          if (bestSeason.value != null)
            SliverToBoxAdapter(
              child: SeasonTile(bestSeason: bestSeason.value!),
            ),
        ],
        body: TabBarView(
          children: [
            ImageGrid(
              pinProvider: profileGridEntriesProvider(userId),
              onRefresh: () => ref
                  .read(photoLibraryProvider)
                  .refreshGallery(PhotoScope(userId: userId)),
            ),
            OtherUserAchievementsTab(userId: userId),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final sticks = ref.watch(
              profileGridEntriesProvider(userId).select(
                (pins) => pins.whenOrNull(
                  data: (entries) =>
                      countUniqueContributedSticks(entries).toString(),
                ),
              ),
            );
            return _statItem(context, 'Sticks', sticks ?? '---');
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final likeCount = ref.watch(
              userLikeServiceProvider(
                userId,
              ).select((value) => value.value?.likeCount.toString()),
            );
            return _statItem(context, 'Likes', likeCount ?? '-');
          },
        ),
      ],
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            height: 1.15,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
