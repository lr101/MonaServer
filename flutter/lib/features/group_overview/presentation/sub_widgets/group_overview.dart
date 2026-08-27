import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:buff_lisa/widgets/slivers/season_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/member_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupOverview extends ConsumerStatefulWidget {
  const GroupOverview(
      {super.key, required this.groupId, this.floatingActionButton, this.actions,});

  final String groupId;
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(memberServiceProvider(widget.groupId));
    final group = ref.watch(groupServiceProvider(widget.groupId)).value;
    return CustomAvatarScaffold(
        floatingActionButton: widget.floatingActionButton,
        avatar: ref.watch(groupProfilePictureByIdProvider(widget.groupId)),
        title: Text(group?.name ?? "", style: const TextStyle(fontWeight: FontWeight.bold),),
        actions: widget.actions,
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(icon: Icon(Icons.groups)),
            Tab(icon: Icon(Icons.image)),
        ],),
        boxes: [
          SliverToBoxAdapter(
              child: ListTile(
            title: const Text("Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
            subtitle: Text(
                members.whenOrNull(data: (data) => data.length.toString()) ??
                    0.toString(),),
          ),),
          SliverToBoxAdapter(
              child: ListTile(
            title: const Text("Sticks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
            subtitle: Text(members.whenOrNull(
                    data: (data) =>
                        data.fold(0, (p, e) => p + e.points).toString(),) ??
                0.toString(),),
          ),),
          SliverToBoxAdapter(
              child: ListTile(
            title: const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
            subtitle: group?.description != null
                ? Text(
                    group!.description!,
                    softWrap: true,
                    maxLines: 10,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  )
                : const Icon(Icons.lock),
          ),),
          if (group?.link != null)
            SliverToBoxAdapter(
                    child: ListTile(
                      onTap: () => clickedOnLink(group.link),
                    title: const Row( children: [Text("External Link", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),), Spacer(), Icon(Icons.open_in_new_rounded)]),
                    subtitle: Text(group!.link ?? "No link set", maxLines: 1, overflow: TextOverflow.ellipsis,),),),
          if (group != null && group.visibility != 0)
            SliverToBoxAdapter(
              child: ListTile(
                onTap: ()  => clickedOnInviteCode(group),
                title: const Text("Invite code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
                subtitle:
                    Text(group.inviteUrl ?? "Ups something went wrong"),
              ),
            ),
          if (group?.bestSeason != null)
            SliverToBoxAdapter(
              child: SeasonTile(bestSeason: group!.bestSeason!),
            ),
        ],
        body: TabBarView(controller: _tabController, children: [
          members.when(
              data: (data) => ListView.builder(
                    itemBuilder: (context, index) =>
                        MemberTile(memberDto: data[index], adminId: group?.groupAdmin ?? "", ),
                    itemCount: data.length,
                  ),
              error: (err, _) => const Center(child: Text("Ups something went wrong")),
              loading: () => const Center(child: CircularProgressIndicator()),),
          ImageGrid(
            pinProvider: sortedGroupPinsProvider(widget.groupId),
          ),
        ],),);
  }



  void clickedOnInviteCode(GroupEntity? group) {
    if (group?.inviteUrl != null) {
      Clipboard.setData(ClipboardData(text: group!.inviteUrl!));
    }
  }
}
