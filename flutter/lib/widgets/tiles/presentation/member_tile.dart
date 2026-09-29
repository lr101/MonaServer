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
    final listTile = ListTile(
      minTileHeight: 60,
      tileColor: userId == memberDto.userId
          ? Theme.of(context).highlightColor
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(memberDto.username),
          Row(
            children: [
              if (isGroupLeader)
                Tooltip(
                  message: 'Group leader',
                  child: Icon(
                    Icons.shield_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.primaryOnSurface,
                  ),
                ),
              if (isGroupLeader) const SizedBox(width: 5),
              if (batch != null)
                Batch(batchId: batch, fontSize: 10, colorOverride: batchColor),
            ],
          ),
        ],
      ),
      leading: SmallProfilePicture.user(userId: memberDto.userId, radius: 22),
      trailing: Text("${memberDto.points} sticks"),
    );
    if (isCurrentUser) {
      return listTile;
    } else {
      return GestureDetector(
        onTap: () => context.pushNamed(
          "userProfile",
          pathParameters: {"id": memberDto.userId},
        ),
        child: listTile,
      );
    }
  }
}
