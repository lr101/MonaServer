import 'package:buff_lisa/app/app_links.dart';
import 'package:buff_lisa/data/config/api_host.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_panel.dart';
import 'package:buff_lisa/features/progression/presentation/group_xp_panel.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/member_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupOverview extends ConsumerStatefulWidget {
  const GroupOverview({
    super.key,
    required this.groupId,
    required this.details,
    this.floatingActionButton,
    this.actions,
  });

  final String groupId;
  final GroupDetailsState details;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

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
    final group = widget.details.group;
    return CustomAvatarScaffold(
      floatingActionButton: widget.floatingActionButton,
      avatar: widget.details.profileImage,
      title: Text(
        group?.name ?? "",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: widget.actions,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            icon: Icon(Icons.groups_outlined),
            text: 'Members',
            iconMargin: EdgeInsets.zero,
          ),
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
      boxes: [
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Members",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              members.whenOrNull(data: (data) => data.length.toString()) ??
                  0.toString(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Sticks",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              members.whenOrNull(
                    data: (data) =>
                        data.fold(0, (p, e) => p + e.points).toString(),
                  ) ??
                  0.toString(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text(
              "Description",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: group?.description != null
                ? Text(
                    group!.description!,
                    softWrap: true,
                    maxLines: 10,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  )
                : const Icon(Icons.lock),
          ),
        ),
        if (group?.link != null)
          SliverToBoxAdapter(
            child: ListTile(
              onTap: () => clickedOnLink(group.link),
              title: const Row(
                children: [
                  Text(
                    "External Link",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Icon(Icons.open_in_new_rounded),
                ],
              ),
              subtitle: Text(
                group!.link ?? "No link set",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (group != null && group.visibility != 0)
          SliverToBoxAdapter(
            child: ListTile(
              onTap: () => clickedOnInviteCode(group),
              trailing: IconButton(
                tooltip: 'Copy invite link',
                onPressed: () => clickedOnInviteLink(group),
                icon: const Icon(Icons.link),
              ),
              title: const Text(
                "Invite code",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(group.inviteUrl ?? "Ups something went wrong"),
            ),
          ),
        if (group?.bestSeason != null)
          SliverToBoxAdapter(child: SeasonTile(bestSeason: group!.bestSeason!)),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          members.when(
            data: (data) => ListView.builder(
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
          ImageGrid(pinProvider: groupDetailsPinsProvider(widget.groupId)),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              GroupXpPanel(groupId: widget.groupId),
              const SizedBox(height: 12),
              GroupAchievementsPanel(groupId: widget.groupId, group: group),
            ],
          ),
        ],
      ),
    );
  }

  void clickedOnInviteCode(GroupEntity? group) {
    if (group?.inviteUrl != null) {
      Clipboard.setData(ClipboardData(text: group!.inviteUrl!));
    }
  }

  Future<void> clickedOnInviteLink(GroupEntity? group) async {
    final inviteCode = group?.inviteUrl;
    if (group == null || inviteCode == null) return;

    final link = groupInviteShareLink(
      apiHost: resolveApiHost(configuredHost: dotenv.env['API_HOST']),
      groupId: group.groupId,
      inviteCode: inviteCode,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invite link copied')));
  }
}
