import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
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

    return GestureDetector(
      onTap: () => _showFilterSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.transparent,
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
                              color: theme.colorScheme.surfaceContainer,
                            ),
                          ),
                          child: RoundImage(
                            size: 14,
                            imageCallback: ref.watch(
                              groupProfilePictureSmallByIdProvider(
                                orderedIds[i],
                              ),
                            ),
                            child: Container(),
                          ),
                        ),
                      ),
                    if (orderedIds.length > 3 && orderedIds.length != 4)
                      Positioned(
                        left: 3 * 12.0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                            border: Border.all(
                              color: theme.colorScheme.surfaceContainer,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "+${orderedIds.length - 3}",
                              style: TextStyle(
                                fontSize: 8,
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
            const SizedBox(width: 8),
            Icon(Icons.filter_list, size: 16, color: theme.colorScheme.primary),
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
    final orderedIds = ref.watch(groupOrderServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // --- HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Filter Groups",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  for (final groupId in orderedIds) {
                    ref
                        .read(groupActiveServiceProvider.notifier)
                        .toggle(groupId, true);
                  }
                },
                child: const Text("Select All"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Long press to reorder groups",
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // --- REORDERABLE LIST ---
          Expanded(
            child: ReorderableListView.builder(
              key: const ValueKey('group_filter_reorder_list'),
              itemCount: orderedIds.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 8,
                  color: Colors.transparent,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              onReorderItem: (oldIndex, newIndex) {
                final newOrder = reorderGroupIds(
                  orderedIds,
                  oldIndex,
                  newIndex,
                );
                ref.read(groupOrderServiceProvider.notifier).setList(newOrder);
              },
              itemBuilder: (context, index) {
                final groupId = orderedIds[index];

                final groupData = ref
                    .watch(groupServiceProvider(groupId))
                    .value;

                if (groupData == null) {
                  return SizedBox.shrink(key: ValueKey('empty_$groupId'));
                }

                final bool isActive = groupData.isActivated;

                return Container(
                  key: ValueKey("${groupId}_group_filter_reorder_list"),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.1,
                          )
                        : theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),

                    // LEFT: Toggle Visibility
                    leading: GestureDetector(
                      onTap: () => _toggleGroup(groupId, isActive),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          RoundImage(
                            size: 20,
                            imageCallback: ref.watch(
                              groupProfilePictureSmallByIdProvider(groupId),
                            ),
                            child: Container(),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // CENTER: Name
                    title: Text(
                      groupData.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    // Tap tile to toggle
                    onTap: () => _toggleGroup(groupId, isActive),

                    // RIGHT: Drag Handle
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _toggleGroup(String groupId, bool isActive) {
    ref.read(groupActiveServiceProvider.notifier).toggle(groupId, !isActive);
  }
}
