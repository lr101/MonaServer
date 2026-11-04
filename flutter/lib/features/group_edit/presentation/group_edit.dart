import 'dart:convert';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_edit_template/presentation/group_edit_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart' as api;

class GroupEdit extends ConsumerStatefulWidget {
  const GroupEdit({
    super.key,
    required this.groupid,
    this.group,
    this.embedded = false,
    this.footerItems = const [],
  });

  final String groupid;
  final GroupEntity? group;
  final bool embedded;
  final List<Widget> footerItems;

  @override
  ConsumerState<GroupEdit> createState() => _GroupEditState();
}

class _GroupEditState extends ConsumerState<GroupEdit> {
  String? _selectedAdminId;

  @override
  void didUpdateWidget(covariant GroupEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupid != widget.groupid) {
      _selectedAdminId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupDto =
        widget.group ?? ref.watch(groupMetadataProvider(widget.groupid)).value;
    final global = ref.watch(globalDataServiceProvider);
    if (groupDto == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final adminId = _selectedAdminId ?? groupDto.groupAdmin;
    final members =
        ref.watch(memberServiceProvider(groupDto.groupId)).value ??
        const <MemberEntity>[];
    return GroupEditTemplate(
      key: ValueKey(groupDto.groupId),
      groupDto: groupDto,
      embedded: widget.embedded,
      footerItems: widget.footerItems,
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
          if (widget.embedded) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Group updated.')));
          } else {
            Navigator.of(context).pop();
          }
        } else if (result != null) {
          CustomErrorSnackBar.message(message: result);
        }
      },
      rowItems: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Administration',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: adminId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Group admin',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final member in members)
                      DropdownMenuItem<String>(
                        value: member.userId,
                        child: Text(member.username),
                      ),
                    if (!members.any((member) => member.userId == adminId))
                      DropdownMenuItem<String>(
                        value: adminId,
                        child: Text(
                          adminId == global.userId ? 'You' : 'Selected admin',
                        ),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _selectedAdminId = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
