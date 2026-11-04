import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum GroupAction { edit, report, leave }

class GroupActionButton extends ConsumerWidget {
  const GroupActionButton({
    super.key,
    required this.group,
    required this.action,
    this.expanded = false,
  });
  final GroupEntity group;
  final GroupAction action;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(userIdProvider) == group.groupAdmin;
    if (!group.userIsMember || action == GroupAction.edit && !isAdmin) {
      return const SizedBox.shrink();
    }
    final (label, icon) = switch (action) {
      GroupAction.edit => ('Edit group', Icons.edit_outlined),
      GroupAction.report => ('Report group', Icons.flag_outlined),
      GroupAction.leave => ('Leave group', Icons.logout),
    };
    final color = action == GroupAction.leave
        ? Theme.of(context).colorScheme.error
        : null;
    void trigger() => performGroupAction(context, ref, group, action);
    return expanded
        ? ListTile(
            leading: Icon(icon, color: color),
            title: Text(label, style: TextStyle(color: color)),
            onTap: trigger,
          )
        : IconButton(
            tooltip: label,
            onPressed: trigger,
            icon: Icon(icon, color: color),
          );
  }
}

void performGroupAction(
  BuildContext context,
  WidgetRef ref,
  GroupEntity group,
  GroupAction action,
) {
  switch (action) {
    case GroupAction.edit:
      context.pushNamed('groupEdit', pathParameters: {'id': group.groupId});
    case GroupAction.report:
      context.pushNamed(
        'report',
        extra: const ['Report Group'],
        queryParameters: {'groupId': group.groupId},
      );
    case GroupAction.leave:
      final isAdmin = ref.read(userIdProvider) == group.groupAdmin;
      final members =
          ref.read(memberServiceProvider(group.groupId)).value?.length ?? 0;
      CustomDialog.show(
        context,
        acceptText: 'Leave',
        cancelText: 'Cancel',
        title: isAdmin && members == 1
            ? 'Delete this group?'
            : 'Leave this group?',
        onPressed: () => _leaveGroup(ref, context, group),
      );
  }
}

Future<void> _leaveGroup(
  WidgetRef ref,
  BuildContext context,
  GroupEntity group,
) async {
  final route = ModalRoute.of(context);
  final router = GoRouter.of(context);
  final fromSettings = GoRouterState.of(context).name == 'groupSettings';
  final result = await ref
      .read(userGroupServiceProvider.notifier)
      .leaveGroup(group.groupId);
  if (result != null) {
    CustomErrorSnackBar.message(
      message: result,
      type: CustomErrorSnackBarType.error,
    );
    return;
  }
  if (route?.isCurrent == true) {
    if (!fromSettings && router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }
}
