import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';

class GroupRankingTile extends ConsumerWidget {

  final GroupRankingDtoInner groupDto;
  final double height;

  const GroupRankingTile({super.key, required this.groupDto, this.height = 60});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = height / 10;
    return Padding(
      padding:const EdgeInsets.symmetric(vertical: 2.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: _tileColor(groupDto.rankNr),
        ),
        child: ListTile(
          minTileHeight: height,
          onTap: () => context.pushNamed('groupOverview', pathParameters: {"id": groupDto.groupInfoDto!.id}),
          trailing: Text("${groupDto.points}p"),
          title: Text(groupDto.groupInfoDto!.name, style: TextStyle(fontSize: fontSize + 8),),
          subtitle:  Align(
            alignment: Alignment.centerLeft,
           child: groupDto.groupInfoDto!.description == null
               ? Icon(Icons.lock, size: fontSize + 6,)
               : Text(groupDto.groupInfoDto!.description!,
                   overflow: TextOverflow.ellipsis,
                   maxLines: 1,
                   style: TextStyle(
                       fontStyle:  FontStyle.italic,
                       fontSize: fontSize + 4,),
           ),
          ),
          leading: SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (groupDto.rankNr! <= 3) Icon(Icons.emoji_events, color: groupDto.rankNr == 1 ? Colors.yellow : groupDto.rankNr == 2 ? Colors.grey : Colors.brown,) else Text("${groupDto.rankNr}.",),
              RoundImage(imageCallback: ref.watch(groupProfilePictureSmallByIdProvider(groupDto.groupInfoDto!.id)), size: (height - 10) / 2),
            ],
          ),),
        ),
      ),
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
