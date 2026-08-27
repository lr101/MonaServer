import 'dart:convert';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_edit_template/presentation/group_edit_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart' as api;

class GroupCreate extends ConsumerWidget {
  const GroupCreate({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupEditTemplate(
      title: "Create a group",
        onSubmit: (name, description, link, profileImage, visibility) async {
      final createDto = api.CreateGroupDto(
          description: description,
          name: name,
          visibility: visibility,
          profileImage: base64Encode(profileImage.toList()),
          groupAdmin: ref.watch(globalDataServiceProvider).userId!,
          link: link,);
      final result = await ref
          .read(userGroupServiceProvider.notifier)
          .createGroup(createDto);
      if (result == null && context.mounted) {
        Navigator.of(context).pop();
      } else if (result != null) {
        CustomErrorSnackBar.message(message: result);
      }
    },);
  }
}
