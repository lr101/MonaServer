import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupTile extends ConsumerWidget {
  final GroupEntity groupDto;
  final VoidCallback? onTap;
  final bool userCachedImage;
  final bool loadImage;
  final String? imageUrl;
  final Widget? tailing;

  const GroupTile({
    super.key,
    required this.groupDto,
    this.onTap,
    this.userCachedImage = false,
    this.loadImage = true,
    this.imageUrl,
    this.tailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listTile = ListTile(
      trailing: tailing,
      minTileHeight: 60,
      title: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(groupDto.name)),
          Align(
            alignment: Alignment.centerLeft,
            child: groupDto.description == null
                ? const Icon(Icons.lock, size: 12)
                : Text(
                    groupDto.description!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
      leading: SmallProfilePicture.group(
        groupId: groupDto.groupId,
        radius: 22,
        imageUrl: imageUrl,
        cachedImageOnly: userCachedImage,
        loadImage: loadImage,
        placeholderAvatar: !loadImage ? const CircleAvatar(radius: 25) : null,
      ),
    );
    if (onTap == null) {
      return listTile;
    } else {
      return GestureDetector(onTap: onTap, child: listTile);
    }
  }
}
