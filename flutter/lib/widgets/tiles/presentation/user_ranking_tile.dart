import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';

class UserRankingTile extends ConsumerWidget {
  final UserRankingDtoInner user;
  final double height;

  const UserRankingTile({super.key, required this.user, this.height = 60});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    final isCurrentUser = userId == user.userInfoDto!.userId;
    final int? batch;
    if (isCurrentUser) {
      batch = ref.watch(currentUserProvider.select((e) => e.value?.selectedBatch));
    } else {
      batch = user.userInfoDto!.selectedBatch;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
            color: _tileColor(user.rankNr),
            border: Border.all(color: isCurrentUser ? Theme.of(context).highlightColor : Colors.transparent),
          ),
          child: ListTile(
            onTap: () => isCurrentUser ? null : context.pushNamed("userProfile", pathParameters: {"id": user.userInfoDto!.userId}),
            minTileHeight: height,
            title: Text(
              user.userInfoDto!.username,
              style: TextStyle(fontSize: (height / 10) + 8),
            ),
            subtitle: batch != null ? Row(children: [Batch(batchId: batch, fontSize: (height / 10) + 2)],) : null,
            leading: SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (user.rankNr! <= 3)
                    Icon(
                      Icons.emoji_events,
                      color: user.rankNr == 1 ? Colors.yellow
                          : user.rankNr == 2 ? Colors.grey : Colors.brown,
                    )
                  else
                    Text(
                      "${user.rankNr}.",
                    ),
                  RoundImage(
                      imageCallback: ref.watch(
                          getUserProfileSmallProvider(user.userInfoDto!.userId),),
                      size: (height - 10) / 2,),
                ],
              ),
            ),
            trailing: Text("${user.points}p"),
          ),),
    );
  }

  Color? _tileColor(int? rank) {
      switch (rank) {
        case 1:
          return Colors.yellow.withValues(alpha: 0.5);
        case 2:
          return Colors.grey.withValues(alpha: 0.5);
        case 3:
          return Colors.brown.withValues(alpha: 0.5);
        default:
          return null;
      }
  }
}
