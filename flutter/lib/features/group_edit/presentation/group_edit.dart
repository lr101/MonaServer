import 'dart:convert';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/group_edit/service/group_edit_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_edit_template/presentation/group_edit_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart' as api;

class GroupEdit extends ConsumerStatefulWidget {
  const GroupEdit({super.key, required this.groupid});

  final String groupid;

  @override
  ConsumerState<GroupEdit> createState() => _GroupEditState();
}

class _GroupEditState extends ConsumerState<GroupEdit> {
  @override
  Widget build(BuildContext context) {
    final groupDto = ref.watch(groupMetadataProvider(widget.groupid)).value;
    final global = ref.watch(globalDataServiceProvider);
    final adminId = ref.watch(groupEditServiceProvider);
    if (groupDto == null)
      return const Center(child: CircularProgressIndicator());
    return GroupEditTemplate(
      groupDto: groupDto,
      title: "Edit group ${groupDto.name}",
      onSubmit: (name, description, link, profileImage, visibility) async {
        final result = await ref
            .read(userGroupServiceProvider.notifier)
            .updateGroup(
              api.UpdateGroupDto(
                description: description,
                name: name,
                profileImage: base64Encode(profileImage),
                link: link,
                visibility: visibility,
                groupAdmin: adminId,
              ),
              groupDto.groupId,
            );
        if (result == null && context.mounted) {
          Navigator.of(context).pop();
        } else if (result != null) {
          CustomErrorSnackBar.message(message: result);
        }
      },
      rowItems: [
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Group admin:",
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  items:
                      ref
                          .watch(memberServiceProvider(groupDto.groupId))
                          .value
                          ?.map(
                            (e) => DropdownMenuItem<String>(
                              value: e.userId,
                              child: Text(e.username),
                            ),
                          )
                          .toList() ??
                      [
                        DropdownMenuItem<String>(
                          value: global.userId,
                          child: Text(
                            ref.watch(currentUserProvider).value!.username,
                          ),
                        ),
                      ],
                  onChanged: (String? value) {
                    if (value != null) {
                      ref
                          .read(groupEditServiceProvider.notifier)
                          .updateAdminId(value);
                    }
                  },
                  value: adminId,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
