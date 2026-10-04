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
  const PopUpMenuFeed({
    super.key,
    required this.pinDto,
    this.onDownloadPhoto,
    this.isDownloadingPhoto = false,
    this.tooltip = 'Post options',
  });

  final PinEntity pinDto;
  final VoidCallback? onDownloadPhoto;
  final bool isDownloadingPhoto;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    final adminId = ref
        .watch(groupMetadataProvider(pinDto.groupId))
        .whenOrNull(data: (d) => d?.groupAdmin);
    final bool isNotCreator = userId != pinDto.creator;
    return PopupMenuButton<int>(
      tooltip: tooltip,
      itemBuilder: (context) {
        return [
          if (onDownloadPhoto != null)
            CustomMenuItem<int>(
              value: 5,
              title: isDownloadingPhoto ? 'Downloading…' : 'Download photo',
              icon: Icons.download_outlined,
              enabled: !isDownloadingPhoto,
            ),
          CustomMenuItem<int>(
            value: 0,
            title: "Hide post",
            icon: Icons.hide_image_outlined,
          ),
          if (isNotCreator)
            CustomMenuItem<int>(
              value: 1,
              title: "Report post",
              icon: Icons.report,
            ),
          if (isNotCreator)
            CustomMenuItem<int>(
              value: 2,
              title: "Hide user",
              icon: Icons.person_off_outlined,
            ),
          if (isNotCreator)
            CustomMenuItem<int>(
              value: 3,
              title: "Report user",
              icon: Icons.report,
            ),
          if (userId == adminId || !isNotCreator)
            CustomMenuItem<int>(value: 4, title: "Delete", icon: Icons.delete),
        ];
      },
      onSelected: (value) {
        switch (value) {
          case 0:
            final posts = ref.read(hiddenPostsServiceProvider.notifier);
            posts.addHiddenPost(pinDto.pinId);
            _showHiddenFeedback(
              context,
              'Post hidden. Restore it in Settings → Hidden posts.',
              () => posts.removeHiddenPost(pinDto.pinId),
            );
          case 1:
            context.pushNamed(
              "report",
              queryParameters: {"pinId": pinDto.pinId},
              extra: ["Report post"],
            );
          case 2:
            final users = ref.read(hiddenUserServiceProvider.notifier);
            users.addHiddenUser(pinDto.creator);
            _showHiddenFeedback(
              context,
              'User hidden. Restore their posts in Settings → Hidden users.',
              () => users.removeHiddenUser(pinDto.creator),
            );
          case 3:
            context.pushNamed(
              "report",
              queryParameters: {"userId": pinDto.creator},
              extra: ["Report user"],
            );
          case 4:
            _deleteStick(ref, context, ref.read(pinServiceProvider));
          case 5:
            onDownloadPhoto?.call();
        }
      },
    );
  }

  void _showHiddenFeedback(
    BuildContext context,
    String message,
    VoidCallback undo,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  Future<void> _deleteStick(
    WidgetRef ref,
    BuildContext context,
    PinService pinService,
  ) async {
    CustomDialog.show(
      context,
      acceptText: "Delete",
      title: "Delete this sticker?",
      cancelText: "Cancel",
      onPressed: () async {
        final result = await pinService.deletePinFromGroup(
          pinDto.pinId,
          showPrompt: true,
        );
        if (!context.mounted) return;
        if (result == null && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
