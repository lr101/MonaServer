
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_menu_item.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PopUpMenuFeed extends ConsumerWidget {

  const PopUpMenuFeed({super.key, required this.pinDto});

  final PinEntity pinDto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    final pinService = ref.watch(pinServiceProvider);
    final adminId = ref.watch(groupServiceProvider(pinDto.groupId)).whenOrNull(data: (d) => d?.groupAdmin);
    final bool isNotCreator =  userId != pinDto.creator;
    return PopupMenuButton(
        itemBuilder: (context) {
          return [
            if(isNotCreator) CustomMenuItem<int>(
                value: 0,
                title: "Hide post",
                icon: Icons.hide_image,
            ),
            if(isNotCreator) CustomMenuItem<int>(
                value: 1,
                title: "Report post",
              icon: Icons.report,
            ),
            if(isNotCreator) CustomMenuItem<int>(
                value: 2,
                title: "Hide user",
              icon: Icons.hide_source,
            ),
            if(isNotCreator) CustomMenuItem<int>(
                value: 3,
                title: "Report user",
              icon: Icons.report,
            ),
            if (userId == adminId || !isNotCreator) CustomMenuItem<int>(
              value: 4,
              title: "Delete",
              icon: Icons.delete,
            ),
          ];
        },
        onSelected:(value){
          switch (value) {
            case 0: ref.read(hiddenPostsServiceProvider.notifier).addHiddenPost(pinDto.pinId);
            case 1: context.pushNamed("report", queryParameters: {"pinId": pinDto.pinId}, extra: ["Report post"]);
            case 2: ref.read(hiddenUserServiceProvider.notifier).addHiddenUser(pinDto.creator);
            case 3: context.pushNamed("report", queryParameters: {"userId": pinDto.creator}, extra: ["Report user"]);
            case 4: _deleteStick(ref, context, pinService);
          }
        },
    );
  }

  Future<void> _deleteStick(WidgetRef ref, BuildContext context, PinService pinService) async {
    CustomDialog.show(
        context,
        acceptText: "Delete",
        title: "Delete this sticker?",
        cancelText: "Cancel",
        onPressed: () async {
          final result = await pinService.deletePinFromGroup(pinDto.pinId, showPrompt: true);
          if (result == null && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
    },);

  }
}
