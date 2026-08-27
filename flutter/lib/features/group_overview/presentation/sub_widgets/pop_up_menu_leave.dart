import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_menu_item.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PopUpMenuLeave extends ConsumerWidget {

  const PopUpMenuLeave({super.key, required this.groupDto});

  final GroupEntity groupDto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(globalDataServiceProvider).userId == groupDto.groupAdmin;
    final numMembers = ref.watch(memberServiceProvider(groupDto.groupId).select((e) => e.value?.length ?? 0));
    return PopupMenuButton(
        itemBuilder: (context) {
          return [
            CustomMenuItem<int>(
                value: 0,
                title: "Leave Group",
              icon: Icons.group_remove,
            ),
            CustomMenuItem<int>(
                value: 1,
                title: "Report Group",
              icon: Icons.report,
            ),
            if (isAdmin) CustomMenuItem<int>(
                value: 2,
                title: "Edit Group (as admin)",
              icon: Icons.edit,
            ),
          ];
        },
        onSelected:(value){
          switch (value) {
            case 0: CustomDialog.show(context, acceptText: "Leave", title: isAdmin && numMembers == 1 ? "Delete this group?" : "Leave this group?", onPressed: () => leaveGroup(ref, context));
            case 1: context.pushNamed('report', queryParameters: {"issueTypes": const ["Report Group"], "groupId": groupDto.groupId});
            case 2: context.pushNamed('groupEdit', pathParameters: {"id": groupDto.groupId});
          }
        },
    );
  }

  Future<void> leaveGroup(WidgetRef ref, BuildContext context) async {
    final result = await ref.read(userGroupServiceProvider.notifier).leaveGroup(groupDto.groupId);
    if (result != null) {
      CustomErrorSnackBar.message(message: result, type: CustomErrorSnackBarType.error);
      Navigator.of(context).pop();
    }
  }
}
