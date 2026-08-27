import 'package:buff_lisa/data/repository/geo_json_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/view_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_ranking_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/user_ranking_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class RankingSlidingPanel extends ConsumerStatefulWidget {
  const RankingSlidingPanel({super.key, required this.headerPixelHeight});

  final double headerPixelHeight;

  @override
  ConsumerState<RankingSlidingPanel> createState() => _RankingSlidingPanelState();
}

class _RankingSlidingPanelState extends ConsumerState<RankingSlidingPanel> {
  // 1. Add a controller to manipulate the sheet position manually
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  


  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gid = ref.watch(zoomGidProvider);
    final currentGid = gid.$1;
    final regionName = gid.$2 ?? "Unknown Region";

    final view = ref.watch(viewServiceProvider);
    AsyncValue<List<dynamic>?> asyncRankings;
    
    if (currentGid == null) {
      asyncRankings = const AsyncValue.data([]);
    } else if (view == ViewState.group) {
      asyncRankings = ref.watch(groupRankingProvider(currentGid));
    } else {
      asyncRankings = ref.watch(userRankingProvider(currentGid));
    }

    final double screenHeight = MediaQuery.of(context).size.height - kBottomNavigationBarHeight - kToolbarHeight;
    // Define sheet limits
    final double minSize = widget.headerPixelHeight / screenHeight;
    const double maxSize = 0.6;
    final List<double> snapSizes = [minSize, maxSize];

    return NotificationListener<DraggableScrollableNotification>(
      child: DraggableScrollableSheet(
        controller: _sheetController, // Attach our controller
        initialChildSize: minSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        snap: true,
        snapSizes: snapSizes,
        builder: (context, scrollController) {
          final double screenHeight = MediaQuery.of(context).size.height;
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow( // Fast flick down
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onVerticalDragUpdate: (details) {
                    // Convert pixel drag to percentage change
                    final double delta = details.primaryDelta! / screenHeight;
                    final double newSize = (_sheetController.size - delta).clamp(minSize, maxSize);
                    _sheetController.jumpTo(newSize);
                  },
                  onVerticalDragEnd: (details) {
                    // Simple snap logic on release
                    final double currentSize = _sheetController.size;
                    final double velocity = details.velocity.pixelsPerSecond.dy;
                    
                    double target = minSize;
                    if (velocity < -500) {
                      target = maxSize; // Fast flick up
                    } else if (velocity > 500) {
                      target = minSize; // Fast flick down
                    } else {
                      // Closest snap point
                      target = (currentSize - minSize).abs() < (currentSize - maxSize).abs() 
                          ? minSize 
                          : maxSize;
                    }
                    
                    _sheetController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  },
                  child: _buildHeaderContent(context, theme, regionName, asyncRankings, view),
                ),

                

                Expanded(
                  child: ClipRect(
                    child: CustomScrollView(
                      controller: scrollController, // Linked to sheet logic
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 10,),),
                        _buildRankingList(asyncRankings, view),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  
  dynamic _getMyRanking(List<dynamic>? rankings, ViewState view) {
    if (rankings == null || rankings.isEmpty) return null;

    if (view == ViewState.group) {
      final myUserGroups = ref.read(userGroupServiceProvider).value ?? [];
      final myGroupIds = myUserGroups.map((e) => e.groupId).toSet();
      
      try {
        return rankings.firstWhere(
          (r) => r is GroupRankingDtoInner && myGroupIds.contains(r.groupInfoDto?.id)
        );
      } catch (e) {
        return null;
      }
    } else {
      // Find the user's own ranking entry
      final myUserId = ref.read(userIdProvider);
      try {
        return rankings.firstWhere(
          (r) => r is UserRankingDtoInner && r.userInfoDto?.userId == myUserId
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
      height: widget.headerPixelHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        // Flexible allows Text to shrink and show ellipsis
                        Flexible(
                          child: Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              overflow: TextOverflow.ellipsis, // Critical for long names
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (myRankItem != null) ...[
                    const SizedBox(width: 18),
                    _buildMyRankBadge(
                      context, 
                      theme, 
                      myRankItem, 
                      view, 
                      asyncRankings.value?.length
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyRankBadge(BuildContext context, ThemeData theme, dynamic item, ViewState view, int? length) {
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
        RoundImage(imageCallback: item is GroupRankingDtoInner 
            ? ref.watch(groupProfilePictureSmallByIdProvider(id))
            : ref.watch(getUserProfileSmallProvider(id)),
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(
          "#$rank of ${length ?? 0}",
          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }



   Widget _buildRankingList(AsyncValue<List<dynamic>?> asyncRankings, ViewState view) {

    return asyncRankings.when(
      data: (rankings) {
        if (rankings == null || rankings.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("No ranking data available")),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (view == ViewState.group) {
                return listBuilderGroup(context, rankings[index] as GroupRankingDtoInner, index);
              } else {
                return listBuilderUser(context, rankings[index] as UserRankingDtoInner, index);
              }
            },
            childCount: rankings.length,
          ),
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
    return GroupRankingTile(
      groupDto: item,
      height: 40,
    );
  }

  Widget listBuilderUser(
    BuildContext context,
    UserRankingDtoInner item,
    int index,
  ) {
    return UserRankingTile(
      user: item,
      height: 40,
    );
  }
}
