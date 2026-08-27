import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/util/types/achievement.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
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
    final int? batch;
    if (isCurrentUser) {
       batch = ref.watch(currentUserProvider.select((e) => e.value?.selectedBatch));
    } else {
       batch = memberDto.selectedBatch;
    }
      final listTile = ListTile(
        minTileHeight: 60,
      tileColor: userId == memberDto.userId ? Theme.of(context).highlightColor: null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(memberDto.username),
          Row(children: [
            if (memberDto.userId == adminId) Batch(batchId: Achievement.admin.id, fontSize: 10,),
            if (memberDto.userId == adminId) const SizedBox(width: 5,),
            if (batch != null) Batch(batchId: batch, fontSize: 10,),
          ],),
        ],
      ),
      leading: RoundImage(imageCallback: ref.watch(getUserProfileSmallProvider(memberDto.userId)), size: 25.0),
      trailing: Text("${memberDto.points} sticks"),
    );
    if (isCurrentUser) {
      return listTile;
    } else {
      return GestureDetector(
        onTap: () => context.pushNamed("userProfile", pathParameters: {"id": memberDto.userId}),
        child: listTile,
      );
    }
  }
}
