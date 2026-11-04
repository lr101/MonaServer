import 'dart:async';

import 'package:buff_lisa/data/repository/geo_json_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/view_service.dart';
import 'package:buff_lisa/features/navigation/presentation/floating_navigation_dock.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_ranking_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/user_ranking_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

/// Reserve enough room for the two header lines at the active text scale.
double rankingHeaderHeight(BuildContext context, {double minimum = 60}) {
  final theme = Theme.of(context);
  double lineHeight(TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Rankings', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final required =
      20 +
      lineHeight(theme.textTheme.titleSmall) +
      lineHeight(theme.textTheme.bodySmall);
  return required > minimum ? required : minimum;
}

class RankingSlidingPanel extends ConsumerStatefulWidget {
  const RankingSlidingPanel({
    super.key,
    required this.headerPixelHeight,
    this.navigationClearance = 0,
  });

  final double headerPixelHeight;

  /// Space occupied by navigation overlaid on this tray.
  final double navigationClearance;

  @override
  ConsumerState<RankingSlidingPanel> createState() =>
      _RankingSlidingPanelState();
}

class _RankingSlidingPanelState extends ConsumerState<RankingSlidingPanel> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _expanded = false;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _settle(double size) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheetController.jumpTo(size);
    } else {
      unawaited(
        _sheetController.animateTo(
          size,
          duration: navigationTransitionDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gid = ref.watch(zoomGidProvider);
    final currentGid = gid.$1;
    final regionName = gid.$2 ?? 'Region unavailable';

    final view = ref.watch(viewServiceProvider);
    AsyncValue<List<dynamic>?> asyncRankings;

    if (currentGid == null) {
      asyncRankings = const AsyncValue.data([]);
    } else if (view == ViewState.group) {
      asyncRankings = ref.watch(groupRankingProvider(currentGid));
    } else {
      asyncRankings = ref.watch(userRankingProvider(currentGid));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final headerHeight = rankingHeaderHeight(
          context,
          minimum: widget.headerPixelHeight,
        );
        final clearance = widget.navigationClearance.clamp(
          0.0,
          (height - headerHeight).clamp(0.0, double.infinity),
        );
        final maxSize = height <= 0
            ? 1.0
            : ((headerHeight + clearance + 48) / height).clamp(0.6, 1.0);
        final minSize = height <= 0
            ? 0.01
            : ((headerHeight + clearance) / height).clamp(0.01, maxSize);
        final snapSizes = <double>[minSize, if (minSize < maxSize) maxSize];
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            final expanded = notification.extent > (minSize + maxSize) / 2;
            if (expanded != _expanded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && expanded != _expanded) {
                  setState(() => _expanded = expanded);
                }
              });
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: minSize,
            minChildSize: minSize,
            maxChildSize: maxSize,
            snap: true,
            snapSizes: snapSizes,
            builder: (context, scrollController) {
              final double screenHeight = constraints.maxHeight;
              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: widget.navigationClearance > 0
                      ? navigationDockWidth(constraints.maxWidth)
                      : constraints.maxWidth,
                  child: Container(
                    key: const ValueKey('ranking-tray'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: widget.navigationClearance > 0
                          ? BorderRadius.circular(32)
                          : const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          button: true,
                          label: _expanded
                              ? 'Collapse rankings'
                              : 'Expand rankings',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _settle(_expanded ? minSize : maxSize),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  // Convert pixel drag to percentage change
                                  final double delta =
                                      details.primaryDelta! / screenHeight;
                                  final double newSize =
                                      (_sheetController.size - delta).clamp(
                                        minSize,
                                        maxSize,
                                      );
                                  _sheetController.jumpTo(newSize);
                                },
                                onVerticalDragEnd: (details) {
                                  // Simple snap logic on release
                                  final double currentSize =
                                      _sheetController.size;
                                  final double velocity =
                                      details.velocity.pixelsPerSecond.dy;

                                  double target = minSize;
                                  if (velocity < -500) {
                                    target = maxSize; // Fast flick up
                                  } else if (velocity > 500) {
                                    target = minSize; // Fast flick down
                                  } else {
                                    // Closest snap point
                                    target =
                                        (currentSize - minSize).abs() <
                                            (currentSize - maxSize).abs()
                                        ? minSize
                                        : maxSize;
                                  }

                                  _settle(target);
                                },
                                child: _buildHeaderContent(
                                  context,
                                  theme,
                                  regionName,
                                  asyncRankings,
                                  view,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: ClipRect(
                            child: CustomScrollView(
                              controller:
                                  scrollController, // Linked to sheet logic
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 10),
                                ),
                                _buildRankingList(asyncRankings, view),
                                const SliverPadding(
                                  padding: EdgeInsets.only(bottom: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: clearance),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  dynamic _getMyRanking(List<dynamic>? rankings, ViewState view) {
    if (rankings == null || rankings.isEmpty) return null;

    if (view == ViewState.group) {
      final myUserGroups = ref.read(userGroupServiceProvider).value ?? [];
      final myGroupIds = myUserGroups.map((e) => e.groupId).toSet();

      try {
        return rankings.firstWhere(
          (r) =>
              r is GroupRankingDtoInner &&
              myGroupIds.contains(r.groupInfoDto?.id),
        );
      } catch (e) {
        return null;
      }
    } else {
      // Find the user's own ranking entry
      final myUserId = ref.read(userIdProvider);
      try {
        return rankings.firstWhere(
          (r) => r is UserRankingDtoInner && r.userInfoDto?.userId == myUserId,
        );
      } catch (e) {
        return null;
      }
    }
  }

  Widget _buildHeaderContent(
    BuildContext context,
    ThemeData theme,
    String title,
    AsyncValue<List<dynamic>?> asyncRankings,
    ViewState view,
  ) {
    // Extract the specific ranking item for "Me"
    final myRankItem = asyncRankings.value != null
        ? _getMyRanking(asyncRankings.value, view)
        : null;

    return Container(
      width: double.infinity,
      height: rankingHeaderHeight(context, minimum: widget.headerPixelHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // 1. LEFT SIDE: Icon + Title (Flexible to avoid overflow)
                Expanded(
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.leaderboard_outlined, size: 20),
                      ),
                      const SizedBox(width: 8),
                      // Flexible allows Text to shrink and show ellipsis
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rankings',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_more : Icons.expand_less,
                  color: theme.colorScheme.onSurfaceVariant,
                  semanticLabel: '',
                ),
                if (myRankItem != null) ...[
                  const SizedBox(width: 18),
                  Flexible(
                    child: _buildMyRankBadge(
                      context,
                      theme,
                      myRankItem,
                      view,
                      asyncRankings.value?.length,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankBadge(
    BuildContext context,
    ThemeData theme,
    dynamic item,
    ViewState view,
    int? length,
  ) {
    int? rank;
    int? points;
    String? id;

    if (item is GroupRankingDtoInner) {
      rank = item.rankNr;
      points = item.points;
      id = item.groupInfoDto?.id;
    } else if (item is UserRankingDtoInner) {
      rank = item.rankNr;
      points = item.points;
      id = item.userInfoDto?.userId;
    }
    if (rank == null || points == null || id == null) return const SizedBox();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item is GroupRankingDtoInner)
          SmallProfilePicture.group(groupId: id, radius: 9)
        else
          SmallProfilePicture.user(userId: id, radius: 9),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            "#$rank of ${length ?? 0}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingList(
    AsyncValue<List<dynamic>?> asyncRankings,
    ViewState view,
  ) {
    return asyncRankings.when(
      data: (rankings) {
        if (rankings == null || rankings.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("No ranking data available")),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (view == ViewState.group) {
              return listBuilderGroup(
                context,
                rankings[index] as GroupRankingDtoInner,
                index,
              );
            } else {
              return listBuilderUser(
                context,
                rankings[index] as UserRankingDtoInner,
                index,
              );
            }
          }, childCount: rankings.length),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text("Currently unavailable")),
        ),
      ),
    );
  }

  Widget listBuilderGroup(
    BuildContext context,
    GroupRankingDtoInner item,
    int index,
  ) {
    return GroupRankingTile(groupDto: item, height: 40);
  }

  Widget listBuilderUser(
    BuildContext context,
    UserRankingDtoInner item,
    int index,
  ) {
    return UserRankingTile(user: item, height: 40);
  }
}
