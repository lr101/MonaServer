import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupJoinActionButton extends ConsumerWidget {
  final GroupEntity groupDto;

  GroupJoinActionButton({super.key, required this.groupDto});

  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SubmitButton(
      text: "Join",
      onPressed: () async {
        if (groupDto.visibility == 0) {
          final result = await ref
              .read(userGroupServiceProvider.notifier)
              .joinGroup(groupDto.groupId);
          if (result != null) {
            CustomErrorSnackBar.message(message: result);
          } else if (context.mounted){
            Navigator.of(context).pop();
          }
        } else {
          await CustomDialog.show(context,
              acceptText: "Join",
              title: "Join Group",
              child: TextFormField(
                decoration: const InputDecoration(hintText: "Invite code"),
                controller: _textController,
              ), onPressed: () async {
            final result = await ref
                .read(userGroupServiceProvider.notifier)
                .joinGroup(groupDto.groupId, inviteUrl: _textController.text);
            if (result != null) {
              CustomErrorSnackBar.message(message: result);
            } else if (context.mounted) {
              Navigator.of(context).pop();
            }
          },);
        }
      },
    );
  }
}
