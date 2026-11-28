import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_panel.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/member_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupOverview extends ConsumerStatefulWidget {
  const GroupOverview({
    super.key,
    required this.groupId,
    required this.details,
    this.floatingActionButton,
  });

  final String groupId;
  final GroupDetailsState details;
  final Widget? floatingActionButton;

  @override
  ConsumerState<GroupOverview> createState() => _GroupOverviewState();
}

class _GroupOverviewState extends ConsumerState<GroupOverview>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(memberServiceProvider(widget.groupId));
    final pins = ref.watch(groupDetailsPinsProvider(widget.groupId));
    final group = widget.details.group;
    final xp = ref.watch(groupProgressionProvider(widget.groupId)).value;
    final progress = xp == null ? null : XpLevelProgress.fromGroupDto(xp);
    final colors = Theme.of(context).colorScheme;
    return CustomAvatarScaffold(
      toolbarHeight: groupTitleToolbarHeight(
        context,
        group?.name ?? '',
        hasSettingsAction: group?.userIsMember == true,
      ),
      actions: group?.userIsMember == true
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  tooltip: 'Group settings',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHigh,
                    foregroundColor: colors.onSurface,
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.pushNamed(
                    'groupSettings',
                    pathParameters: {'id': widget.groupId},
                  ),
                ),
              ),
            ]
          : null,
      profileContentHeight:
          ((MediaQuery.textScalerOf(context).scale(16) +
                      MediaQuery.textScalerOf(context).scale(12)) *
                  1.2)
              .clamp(88, double.infinity),
      avatarBuilder: progress == null
          ? null
          : (avatar) => UserXpAvatarIndicator(
              progress: progress,
              avatar: avatar,
              radius: 40,
            ),
      floatingActionButton: widget.floatingActionButton,
      remoteAvatar: widget.details.profileImage,
      title: Text(
        group?.name ?? "",
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold, fontSize: 20, height: 1.15),
      ),
      hasBackButton: false,
      profileQuickViewBoxes: _buildQuickStats(members, pins),
      bottom: TabBar(
        controller: _tabController,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: const [
          Tab(
            child: Tooltip(
              message: 'Members',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text('Members', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: Tooltip(
              message: 'Pins',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_on_rounded, size: 17),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text('Pins', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: Tooltip(
              message: 'Achievements',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Achievements',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      boxes: [
        if (group?.userIsMember != true &&
            (group?.description?.isNotEmpty == true ||
                group?.link != null ||
                group?.bestSeason != null))
          SliverToBoxAdapter(
            child: ListTile(
              minTileHeight: 48,
              dense: true,
              title: Text(
                group?.description ?? 'Group information',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(
                Icons.info_outline,
                size: 20,
                semanticLabel: 'Group information',
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (sheetContext) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group?.name ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (group?.description != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(group!.description!),
                          ),
                        if (group?.link != null)
                          ListTile(
                            leading: const Icon(Icons.open_in_new),
                            title: Text(group!.link!),
                            onTap: () => clickedOnLink(group.link),
                          ),
                        if (group?.bestSeason != null)
                          SeasonTile(bestSeason: group!.bestSeason!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          members.when(
            data: (data) => ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) => MemberTile(
                memberDto: data[index],
                adminId: group?.groupAdmin ?? "",
              ),
              itemCount: data.length,
            ),
            error: (err, _) =>
                const Center(child: Text("Ups something went wrong")),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          ImageGrid(
            pinProvider: groupPinEntriesProvider(widget.groupId),
            onRefresh: () {
              _retryGroupPins();
              return ref
                  .read(photoLibraryProvider)
                  .refreshGallery(PhotoScope(groupId: widget.groupId));
            },
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              GroupAchievementsPanel(groupId: widget.groupId, group: group),
            ],
          ),
        ],
      ),
    );
  }

  void _retryGroupPins() {
    ref
        .read(pinGroupRefreshErrorStateProvider(widget.groupId).notifier)
        .clear();
    ref.invalidate(pinGroupServiceUnfilteredProvider(widget.groupId));
  }

  Widget _buildQuickStats(
    AsyncValue<List<MemberEntity>> members,
    AsyncValue<List<PinEntity>?> pins,
  ) {
    final stats = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _statItem(
            'Members',
            members.whenOrNull(data: (data) => data.length.toString()) ?? '0',
          ),
        ),
        Expanded(
          child: pins.hasError
              ? TextButton(
                  onPressed: _retryGroupPins,
                  child: const Text('Retry sticks'),
                )
              : _statItem(
                  'Sticks',
                  pins.whenOrNull(
                        data: (values) => (values ?? const <PinEntity>[])
                            .map((entry) => entry.pinId)
                            .toSet()
                            .length
                            .toString(),
                      ) ??
                      '0',
                ),
        ),
      ],
    );
    return stats;
  }

  Widget _statItem(String label, String value) {
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Fit the group name before allocating the avatar and tabs below it.
double groupTitleToolbarHeight(
  BuildContext context,
  String name, {
  bool hasSettingsAction = false,
}) {
  final painter =
      TextPainter(
        text: TextSpan(
          text: name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            height: 1.15,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 3,
      )..layout(
        maxWidth:
            (MediaQuery.sizeOf(context).width -
                    88 -
                    (hasSettingsAction ? 48 : 0))
                .clamp(1, double.infinity),
      );
  final height = (painter.height + 12).clamp(kToolbarHeight, double.infinity);
  painter.dispose();
  return height;
}
