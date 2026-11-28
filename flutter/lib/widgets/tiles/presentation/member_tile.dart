import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MemberTile extends ConsumerWidget {
  final MemberEntity memberDto;
  final String adminId;

  const MemberTile({super.key, required this.memberDto, required this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    final isCurrentUser = userId == memberDto.userId;
    final isGroupLeader = memberDto.userId == adminId;
    final int? batch;
    final String? batchColor;
    if (isCurrentUser) {
      batch = ref.watch(
        currentUserProvider.select((e) => e.value?.selectedBatch),
      );
      batchColor = ref.watch(
        currentUserProvider.select((e) => e.value?.selectedBatchColor),
      );
    } else {
      batch = memberDto.selectedBatch;
      batchColor = memberDto.selectedBatchColor;
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final listTile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      minTileHeight: 62,
      onTap: isCurrentUser
          ? null
          : () => context.pushNamed(
              "userProfile",
              pathParameters: {"id": memberDto.userId},
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  memberDto.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(
                      alpha: isLight ? 0.22 : 0.24,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'You',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primaryOnSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isGroupLeader || batch != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (isGroupLeader)
                  Tooltip(
                    message: 'Group leader',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Admin',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isGroupLeader && batch != null) const SizedBox(width: 8),
                if (batch != null)
                  Batch(batchId: batch, fontSize: 10, colorOverride: batchColor),
              ],
            ),
          ],
        ],
      ),
      leading: SmallProfilePicture.user(userId: memberDto.userId, radius: 22),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          "${memberDto.points} sticks",
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: listTile,
        ),
      ),
    );
  }
}
