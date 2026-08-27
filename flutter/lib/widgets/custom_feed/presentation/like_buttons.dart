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

  const FeedCardSubtitle({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinLike = ref.watch(likeServiceProvider(pin.pinId));
    final userId = ref.watch(globalDataServiceProvider).userId!;
    // Watch the group data to display the name
    final groupAsync = ref.watch(groupServiceProvider(pin.groupId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ACTION ROW (Likes, etc.)
        Row(
          children: [
            LikeButtonAnimated(
              isLikedProvider: likeServiceProvider(pin.pinId).select((e) => e.value?.likedByUser),
              isLiked: pinLike.value?.likedByUser ?? false,
              likeBuilder: (isLiked) {
                return Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface,
                  size: 26,
                );
              },
              likeCount: pinLike.value?.likeCount ?? 0,
              onTap: (isLiked) async {
                try {
                  final service = ref.read(likeServiceProvider(pin.pinId).notifier);
                  if (isLiked) {
                    await service.addLike(pin.creator, CreateLikeDto(userId: userId, like: false));
                  } else {
                    await service.addLike(pin.creator, CreateLikeDto(userId: userId, like: true));
                  }
                } catch (e) {
                  return false;
                }
                return true;
              },
            ),
      

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("•", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            
            groupAsync.when(
              data: (group) => ClickableGroup(groupId: group?.groupId ?? "", child:  Text(
                group?.name ?? "",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
              )),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const Text("Unknown Group"),
            ),
            
            // Separator dot
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("•", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),

            // Time Ago
            Text(
              _formatTimeAgo(pin.creationDate), 
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey, fontSize: 12),
            ),
                

          ]
        ),
        if (pin.description != null && pin.description!.isNotEmpty)
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
