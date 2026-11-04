import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
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
      if (!mounted) return;
      updatePage(ref.read(userGroupServiceProvider).value?.toList() ?? []);
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      orderedGroupsProvider,
      (_, next) => updatePage(next.value ?? []),
    );
    return CustomScaffold<GroupEntity>(
      title: Row(
        children: [
          const Flexible(
            child: Text(
              'Your groups',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          if (ref.watch(orderedGroupsProvider).value case final groups?)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${groups.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Find groups',
          onPressed: () => context.pushNamed('groupSearch'),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Create group',
          onPressed: () => context.pushNamed('groupCreate'),
          icon: const Icon(Icons.group_add_outlined),
        ),
      ],
      listBuilder: (context, item, index) =>
          GroupTile(groupDto: item, onTap: () => openGroupOverview(item)),
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
