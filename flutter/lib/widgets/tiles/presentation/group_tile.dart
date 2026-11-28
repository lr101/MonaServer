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
  final bool inGrid;

  const GroupTile({
    super.key,
    required this.groupDto,
    this.onTap,
    this.userCachedImage = false,
    this.loadImage = true,
    this.imageUrl,
    this.tailing,
    this.inGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final listTile = ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: inGrid ? 8 : 6,
      ),
      trailing:
          tailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                )),
      onTap: onTap,
      minTileHeight: 64,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            groupDto.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: inGrid ? 16 : 15,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          groupDto.description == null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Private group',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: inGrid ? 13.5 : 13,
                      ),
                    ),
                  ],
                )
              : Text(
                  groupDto.description!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: inGrid ? 13.5 : 13,
                    height: 1.3,
                  ),
                ),
        ],
      ),
      leading: SmallProfilePicture.group(
        groupId: groupDto.groupId,
        radius: inGrid ? 25 : 23,
        imageUrl: imageUrl,
        cachedImageOnly: userCachedImage,
        loadImage: loadImage,
        placeholderAvatar: !loadImage ? const CircleAvatar(radius: 23) : null,
      ),
    );
    if (inGrid) {
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Center(child: listTile),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          clipBehavior: Clip.antiAlias,
          child: listTile,
        ),
      ),
    );
  }
}
