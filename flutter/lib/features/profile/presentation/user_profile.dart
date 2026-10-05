import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/presentation/user_achievements_tab.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';

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
    final userPins = ref.watch(userPinEntriesProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final likes = ref.watch(userLikeServiceProvider(userId));
    final profileImage = ref.watch(getUserProfileProvider(userId));

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
      avatar: profileImage,
      avatarEditAction: () => context.pushNamed("profileSettings"),
      title: _buildTitle(currentUser),
      actions: _buildActions(context),
      hasBackButton: widget.hasBackButton,
      profileQuickViewBoxes: _buildQuickStats(userPins, likes, ref),
      bottom: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            icon: Icon(Icons.image_outlined),
            text: 'Pins',
            iconMargin: EdgeInsets.zero,
          ),
          Tab(
            icon: Icon(Icons.emoji_events_outlined),
            text: 'Achievements',
            iconMargin: EdgeInsets.zero,
          ),
        ],
      ),
      boxes: _buildDetailList(currentUser),
      body: TabBarView(
        controller: _tabController,
        children: [
          ImageGrid(pinProvider: userPinEntriesProvider(userId)),
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
    return [
      IconButton(
        tooltip: "Settings",
        onPressed: () => context.pushNamed("settings"),
        icon: const Icon(Icons.settings),
      ),
    ];
  }

  Widget _buildQuickStats(
    AsyncValue<List<PinEntity>> userPins,
    AsyncValue<UserLikesDto> likes,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(
          "Sticks",
          userPins.whenOrNull(
                data: (entries) =>
                    countUniqueContributedSticks(entries).toString(),
              ) ??
              "---",
        ),
        _statItem(
          "Groups",
          ref.watch(userGroupServiceProvider).value?.length.toString() ?? "---",
        ),
        _statItem("Likes", likes.value?.likeCount.toString() ?? "-"),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<SliverToBoxAdapter> _buildDetailList(
    AsyncValue<UserEntity?> currentUser,
  ) {
    return [
      if (currentUser.value?.description != null)
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Description",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              currentUser.value!.description!,
              softWrap: true,
              maxLines: 10,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      if (currentUser.value?.bestSeason != null)
        SliverToBoxAdapter(
          child: SeasonTile(bestSeason: currentUser.value!.bestSeason!),
        ),
    ];
  }
}
