import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_group.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_description.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_button_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class FeedCardSubtitle extends ConsumerWidget {
  final PinEntity pin;
  final bool showDescription;
  final bool showContext;
  final bool animateLikeChanges;

  const FeedCardSubtitle({
    super.key,
    required this.pin,
    this.showDescription = true,
    this.showContext = true,
    this.animateLikeChanges = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinLike = ref.watch(likeServiceProvider(pin.entryId));
    final userId = ref.watch(globalDataServiceProvider).userId;
    // Watch the group data to display the name
    final groupAsync = ref.watch(groupMetadataProvider(pin.groupId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ACTION ROW (Likes, etc.)
        Row(
          children: [
            LikeButtonAnimated(
              isLikedProvider: likeServiceProvider(pin.entryId)
                  .select((e) => e.value?.likedByUser),
              isLiked: pinLike.value?.likedByUser ?? false,
              size: 22,
              likeCountPadding: const EdgeInsets.only(left: 5),
              likeBuilder: (isLiked) {
                return Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked
                      ? const Color(0xFFE53935)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 21,
                );
              },
              likeCount: pinLike.value?.likeCount ?? 0,
              animateLikeChanges: animateLikeChanges,
              mainAxisAlignment: MainAxisAlignment.start,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              onTap: userId == null || !pinLike.hasValue
                  ? null
                  : (isLiked) async {
                      try {
                        final service = ref.read(
                          likeServiceProvider(pin.entryId).notifier,
                        );
                        if (isLiked) {
                          await service.addLike(
                            pin.creator,
                            CreateLikeDto(userId: userId, like: false),
                          );
                        } else {
                          await service.addLike(
                            pin.creator,
                            CreateLikeDto(userId: userId, like: true),
                          );
                        }
                      } catch (e) {
                        return false;
                      }
                      return true;
                    },
            ),

            if (showContext) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  "·",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Flexible(
                child: groupAsync.when(
                  data: (group) => ClickableGroup(
                    groupId: group?.groupId ?? "",
                    child: Text(
                      group?.name ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.84,
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => Text(
                    "Unknown Group",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),

              // Separator dot
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  "·",
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Time Ago
              Text(
                _formatTimeAgo(pin.creationDate),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        if (showDescription &&
            pin.description != null &&
            pin.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: FeedDescriptionExpandable(pin: pin),
          ),
      ],
    );
  }

  // Simple helper to format time like "2h", "5d"
  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()}y";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo";
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "now";
  }
}
