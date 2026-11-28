import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/presentation/user_achievements_tab.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserProfile extends ConsumerStatefulWidget {
  const UserProfile({
    super.key,
    this.initialTabIndex = 0,
    this.hasBackButton = false,
  });

  final int initialTabIndex;
  final bool hasBackButton;

  @override
  ConsumerState<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends ConsumerState<UserProfile>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    final currentUser = ref.watch(currentUserProvider);

    final xp = ref.watch(userXpProvider(userId)).value;
    final progress = xp == null ? null : XpLevelProgress.fromDto(xp);
    return CustomAvatarScaffold(
      avatarBuilder: progress == null
          ? null
          : (avatar) => UserXpAvatarIndicator(
              progress: progress,
              avatar: avatar,
              radius: 40,
            ),
      remoteAvatar: RemoteImageReference(
        kind: RemoteImageKind.user,
        id: userId,
      ),
      avatarEditAction: () => context.pushNamed("profileSettings"),
      title: _buildTitle(currentUser),
      actions: _buildActions(context),
      hasBackButton: widget.hasBackButton,
      profileQuickViewBoxes: _buildQuickStats(userId),
      bottom: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: const [
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
      boxes: _buildDetailList(currentUser),
      body: TabBarView(
        controller: _tabController,
        children: [
          ImageGrid(
            pinProvider: profileGridEntriesProvider(userId),
            header: _buildBioHeader(currentUser),
            onRefresh: () => ref
                .read(photoLibraryProvider)
                .refreshGallery(PhotoScope(userId: userId)),
          ),
          const UserAchievementsTab(),
        ],
      ),
    );
  }

  Widget _buildTitle(AsyncValue<UserEntity?> currentUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            currentUser.value?.username ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        if (currentUser.value?.selectedBatch != null)
          GestureDetector(
            child: Batch(
              batchId: currentUser.value!.selectedBatch!,
              fontSize: 10,
              colorOverride: currentUser.value!.selectedBatchColor,
            ),
            onTap: () => _tabController.animateTo(1),
          ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: IconButton.filledTonal(
          tooltip: "Settings",
          onPressed: () => context.pushNamed("settings"),
          style: IconButton.styleFrom(
            backgroundColor: colors.surfaceContainerHigh,
            foregroundColor: colors.onSurface,
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ),
    ];
  }

  Widget _buildQuickStats(String userId) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    return Row(
      mainAxisAlignment: isWide
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.spaceEvenly,
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
            return _statItem("Sticks", sticks ?? "---", isWide: isWide);
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final groups = ref.watch(
              userGroupServiceProvider.select(
                (value) => value.value?.length.toString(),
              ),
            );
            return _statItem("Groups", groups ?? "---", isWide: isWide);
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final likeCount = ref.watch(
              userLikeServiceProvider(
                userId,
              ).select((value) => value.value?.likeCount.toString()),
            );
            return _statItem("Likes", likeCount ?? "-", isWide: isWide);
          },
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, {bool isWide = false}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isWide ? 22 : 20,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isWide ? 13.5 : 12.5,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget? _buildBioHeader(AsyncValue<UserEntity?> currentUser) {
    final theme = Theme.of(context);
    final description = currentUser.value?.description?.trim();
    if (description == null || description.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        description,
        softWrap: true,
        maxLines: 10,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }

  List<SliverToBoxAdapter> _buildDetailList(
    AsyncValue<UserEntity?> currentUser,
  ) {
    return [
      if (currentUser.value?.bestSeason != null)
        SliverToBoxAdapter(
          child: SeasonTile(bestSeason: currentUser.value!.bestSeason!),
        ),
    ];
  }
}
