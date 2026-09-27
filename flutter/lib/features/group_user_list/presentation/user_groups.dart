import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/group_user_list/presentation/pop_up_menu_create_group.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_scaffold.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class UserGroups extends ConsumerStatefulWidget {
  const UserGroups({super.key});

  @override
  ConsumerState<UserGroups> createState() => _UserGroupsState();
}

class _UserGroupsState extends ConsumerState<UserGroups> {

  final _pagingController = PagingController<int, GroupEntity>(firstPageKey: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updatePage(ref.watch(userGroupServiceProvider).value?.toList() ?? []);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
  
  
  @override
  Widget build(BuildContext context) {
    ref.listen(orderedGroupsProvider, (_, next) => updatePage(next.value ?? []));
    return CustomScaffold<GroupEntity>(
        title: const Text("Your groups", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [PopUpMenuCreateGroup()],
        listBuilder: (context, item, index) => GroupTile(
          groupDto: item,
          onTap: () => openGroupOverview(item),
        ),
        pagingController: _pagingController,
    );
  }
  
  void updatePage(List<GroupEntity> groups) {
    _pagingController.refresh();
    _pagingController.appendLastPage(groups);
  }

  void openGroupOverview(GroupEntity group) {
    context.pushNamed('groupOverview', pathParameters: {"id": group.groupId});
  }

}
