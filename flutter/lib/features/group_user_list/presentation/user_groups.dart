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
  final _pagingController = PagingController<int, GroupEntity>(
    getNextPageKey: (_) => null,
    fetchPage: (_) => <GroupEntity>[],
  );

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return CustomScaffold<GroupEntity>(
      maxWidth: 880,
      gridColumnsBuilder: (width) => width >= 720 ? 2 : 1,
      gridMainAxisExtent: 102,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: isLight ? 0.28 : 0.26),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${groups.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isLight ? const Color(0xFF8A4F00) : colors.primary,
                ),
              ),
            ),
        ],
      ),
      actions: isWide
          ? [
              OutlinedButton.icon(
                onPressed: () => context.pushNamed('groupSearch'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: colors.outlineVariant),
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Find groups'),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.icon(
                  onPressed: () => context.pushNamed('groupCreate'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New group'),
                ),
              ),
            ]
          : [
              IconButton.filledTonal(
                tooltip: 'Find groups',
                onPressed: () => context.pushNamed('groupSearch'),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHigh,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  tooltip: 'Create group',
                  onPressed: () => context.pushNamed('groupCreate'),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHigh,
                    foregroundColor: colors.onSurface,
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                ),
              ),
            ],
      listBuilder: (context, item, index) => GroupTile(
        groupDto: item,
        inGrid: isWide,
        onTap: () => openGroupOverview(item),
      ),
      emptyState: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No groups yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join a public crew or start your own group to share stickers on the map.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.pushNamed('groupSearch'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Find groups'),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.pushNamed('groupCreate'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Create group'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      pagingController: _pagingController,
    );
  }

  void updatePage(List<GroupEntity> groups) {
    _pagingController.cancel();
    _pagingController.value = PagingState(
      pages: [groups],
      keys: [0],
      hasNextPage: false,
    );
  }

  void openGroupOverview(GroupEntity group) {
    context.pushNamed('groupOverview', pathParameters: {"id": group.groupId});
  }
}
