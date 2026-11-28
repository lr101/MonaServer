import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

List<String> reorderGroupIds(
  List<String> orderedIds,
  int oldIndex,
  int newIndex,
) {
  final newOrder = List<String>.from(orderedIds);
  final item = newOrder.removeAt(oldIndex);
  newOrder.insert(newIndex, item);
  return newOrder;
}

class GroupFilterWidget extends ConsumerWidget {
  const GroupFilterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final orderedIds = ref.watch(groupActiveServiceProvider);

    return Tooltip(
      message: 'Filter groups',
      child: TextButton(
        onPressed: () => _showFilterSheet(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- STACKED AVATARS ---
            if (orderedIds.isEmpty)
              Icon(
                Icons.visibility_off,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              )
            else
              SizedBox(
                width: _calculateWidth(orderedIds.length),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    for (
                      int i = 0;
                      i < orderedIds.length &&
                          (i < 3 || orderedIds.length == 4);
                      i++
                    )
                      Positioned(
                        left: i * 12.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.brightness ==
                                      Brightness.light
                                  ? theme.colorScheme.surfaceContainerLowest
                                  : theme.colorScheme.surfaceContainerHigh,
                              width: 2,
                            ),
                          ),
                          child: SmallProfilePicture.group(
                            groupId: orderedIds[i],
                            radius: 11,
                          ),
                        ),
                      ),
                    if (orderedIds.length > 3 && orderedIds.length != 4)
                      Positioned(
                        left: 3 * 12.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                            border: Border.all(
                              color: theme.colorScheme.brightness ==
                                      Brightness.light
                                  ? theme.colorScheme.surfaceContainerLowest
                                  : theme.colorScheme.surfaceContainerHigh,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "+${orderedIds.length - 3}",
                              style: TextStyle(
                                fontSize: 9,
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.tune_rounded,
              size: 21,
              color: theme.colorScheme.primaryOnSurface,
            ),
          ],
        ),
      ),
    );
  }

  double _calculateWidth(int count) {
    if (count == 0) return 0;
    final int visibleCount = count > 3 ? 4 : count;
    return 14 + visibleCount * 14.0;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _FilterSheetContent(),
    );
  }
}

class _FilterSheetContent extends ConsumerStatefulWidget {
  const _FilterSheetContent();

  @override
  ConsumerState<_FilterSheetContent> createState() =>
      _FilterSheetContentState();
}

class _FilterSheetContentState extends ConsumerState<_FilterSheetContent> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = colors.brightness == Brightness.light;
    final orderedIds = ref.watch(groupOrderServiceProvider);
    final activeIds = ref.watch(groupActiveServiceProvider);
    final allSelected =
        orderedIds.isNotEmpty &&
        orderedIds.every((id) => activeIds.contains(id));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.68,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Filter groups",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tap to toggle · drag to reorder",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: allSelected
                        ? null
                        : () {
                            for (final groupId in orderedIds) {
                              ref
                                  .read(groupActiveServiceProvider.notifier)
                                  .toggle(groupId, true);
                            }
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: allSelected
                          ? Colors.transparent
                          : colors.primary.withValues(
                              alpha: isLight ? 0.22 : 0.18,
                            ),
                      foregroundColor: allSelected
                          ? colors.onSurfaceVariant
                          : colors.primaryOnSurface,
                      disabledForegroundColor: colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(allSelected ? "All active" : "Select all"),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text("Done"),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ReorderableListView.builder(
                  key: const ValueKey('group_filter_reorder_list'),
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: orderedIds.length,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 6,
                      color: Colors.transparent,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    );
                  },
                  onReorderItem: (oldIndex, newIndex) {
                    final newOrder = reorderGroupIds(
                      orderedIds,
                      oldIndex,
                      newIndex,
                    );
                    ref
                        .read(groupOrderServiceProvider.notifier)
                        .setList(newOrder);
                  },
                  itemBuilder: (context, index) {
                    final groupId = orderedIds[index];
                    final groupData = ref
                        .watch(groupMetadataProvider(groupId))
                        .value;

                    if (groupData == null) {
                      return SizedBox.shrink(key: ValueKey('empty_$groupId'));
                    }

                    final bool isActive = groupData.isActivated;

                    return Container(
                      key: ValueKey("${groupId}_group_filter_reorder_list"),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isLight
                            ? colors.surfaceContainerLow
                            : colors.surfaceContainerHigh.withValues(
                                alpha: isActive ? 0.9 : 0.45,
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(
                            alpha: isActive ? 0.85 : 0.55,
                          ),
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? colors.primaryContainer
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isActive
                                      ? colors.primaryContainer
                                      : colors.outline,
                                  width: 1.8,
                                ),
                              ),
                              child: isActive
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: colors.onPrimaryContainer,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Opacity(
                              opacity: isActive ? 1.0 : 0.55,
                              child: SmallProfilePicture.group(
                                groupId: groupId,
                                radius: 17,
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          groupData.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => _toggleGroup(groupId, isActive),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                size: 22,
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleGroup(String groupId, bool isActive) {
    ref.read(groupActiveServiceProvider.notifier).toggle(groupId, !isActive);
  }
}
