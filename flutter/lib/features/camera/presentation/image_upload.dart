import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/camera/data/app_review_state.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:select_dialog/select_dialog.dart';
import 'package:uuid/uuid.dart';

class ImageUpload extends ConsumerStatefulWidget {
  const ImageUpload({super.key, required this.image, required this.position});

  final Uint8List image;
  final LatLng position;

  @override
  ConsumerState<ImageUpload> createState() => _ImageUploadState();
}

class _ImageUploadState extends ConsumerState<ImageUpload> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late int _groupIndexWhenOpened;
  bool _approvalStarted = false;

  @override
  void initState() {
    super.initState();
    _groupIndexWhenOpened = ref.read(cameraGroupIndexProvider);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(cameraSelectedGroupProvider);
    final groupId = group.value?.groupId;
    if (groupId != null) {
      ref.watch(pinServiceProvider);
    }

    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return CustomCloseKeyboardScaffold(
      appBar: AppBar(
        title: const Text(
          "Approve",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.33,
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Image.memory(
                            widget.image,
                            height: MediaQuery.of(context).size.height * 0.33,
                            fit: BoxFit.fitHeight,
                          ),
                        ),
                      ),
                    ),
                    if (group.value != null)
                      Card(
                        child: GroupTile(
                          groupDto: group.value!,
                          onTap: handleEdit,
                        ),
                      )
                    else
                      const Card(),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                                hintText: 'Give this pin a short title',
                                counterText: '',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 1,
                              maxLines: 10,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Add a note about this place',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.multiline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Visibility(
            visible: !isKeyboardVisible,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: SubmitButton(
                onPressed: handleApprove,
                text: "Upload",
                showLoadingIndicator: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> handleApprove() {
    if (_approvalStarted) return Future<void>.value();
    final groupId = groupIdAt(
      ref.read(groupOrderServiceProvider),
      ref.read(cameraGroupIndexProvider),
    );
    if (groupId == null) return Future<void>.value();
    _approvalStarted = true;
    final pin = PinEntity(
      pinId: const Uuid().v4(),
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      creationDate: DateTime.now(),
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      creator: ref.read(globalDataServiceProvider).userId!,
      groupId: groupId,
      onlySession: false,
      keepAlive: true,
      ttl: DateTime.now(),
    );
    final reviewState = !kIsWeb && ref.read(appReviewStateProvider)
        ? ref.read(appReviewStateProvider.notifier)
        : null;
    // Start persistence before leaving; PinService starts upload only after the
    // complete post and image have committed to the outbox.
    unawaited(
      ref
          .read(pinServiceProvider)
          .addPinToGroup(pin, widget.image)
          .then<void>(
            (saveError) {
              if (saveError == null) {
                CustomErrorSnackBar.message(
                  message: "Image saved",
                );
                if (reviewState != null) {
                  unawaited(postUploadActions(reviewState));
                }
              } else {
                CustomErrorSnackBar.message(
                  message:
                      "Could not save post on this device. Please try again.",
                  type: CustomErrorSnackBarType.error,
                );
              }
            },
            onError: (Object _, StackTrace __) {
              CustomErrorSnackBar.message(
                message:
                    "Could not save post on this device. Please try again.",
                type: CustomErrorSnackBarType.error,
              );
            },
          ),
    );
    ref
        .read(cameraGroupIndexProvider.notifier)
        .updateIndex(_groupIndexWhenOpened);
    if (!mounted) return Future<void>.value();
    Navigator.of(context).popUntil((route) => route.isFirst);
    return Future<void>.value();
  }

  Future<void> postUploadActions(AppReviewState reviewState) async {
    reviewState.updateLastReviewDate();
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    }
  }

  Future<void> handleEdit() async {
    final groups = ref.read(groupOrderServiceProvider);
    await SelectDialog.showModal<String>(
      context,
      showSearchBox: false,
      label: const Text("Change Group"),
      selectedValue: groups[ref.watch(cameraGroupIndexProvider)],
      itemBuilder: (context, group, b) => GroupTile(
        groupDto: ref
            .read(userGroupServiceProvider)
            .value!
            .firstWhere((e) => e.groupId == group),
      ),
      items: groups,
      onChange: (group) {
        ref
            .read(cameraGroupIndexProvider.notifier)
            .updateIndex(groups.indexOf(group));
      },
    );
  }
}
