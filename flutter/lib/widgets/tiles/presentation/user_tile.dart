import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserTile extends ConsumerWidget {
  final String userId;

  const UserTile({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userByIdUsernameProvider(userId));
    return ListTile(
      minTileHeight: 60,
          onTap: () => CustomDialog.show(context,
            acceptText: "Remove",
            title: "Remove hidden user",
            onPressed: () => ref.read(hiddenUserServiceProvider.notifier).removeHiddenUser(userId),),
          title: Align(alignment: Alignment.centerLeft, child: Text(user.value ?? "")),
          leading: RoundImage(
                imageCallback: ref.watch(getUserProfileSmallProvider(userId)),
                size: 25.0,
                child: Container(),),
            );
  }
}
