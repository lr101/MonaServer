import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/camera/data/app_review_state.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';
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
  bool _checkingLocation = true;
  bool _markSelectedPinGone = false;
  Position? _presencePosition;
  String? _selectedUpdatePinId;
  String? _uploadedUpdatePinId;
  final _photoUploadRetry = PinPhotoUploadRetry();

  @override
  void initState() {
    super.initState();
    _groupIndexWhenOpened = ref.read(cameraGroupIndexProvider);
    unawaited(_refreshPresencePosition());
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
    final groupPins = groupId == null
        ? null
        : ref.watch(groupDetailsPinsProvider(groupId));
    final nearbyPins = _nearbySyncedPins(groupPins?.value ?? const []);
    final locked =
        _photoUploadRetry.pendingRequest != null ||
        _uploadedUpdatePinId != null;

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
                          onTap: locked ? null : handleEdit,
                        ),
                      )
                    else
                      const Card(),
                    _nearbyPinPicker(
                      nearbyPins,
                      pinsLoading: groupPins?.isLoading ?? false,
                      locked: locked,
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (_selectedUpdatePinId == null)
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
                              decoration: InputDecoration(
                                labelText: _selectedUpdatePinId == null
                                    ? 'Description'
                                    : 'Photo note (optional)',
                                hintText: _selectedUpdatePinId == null
                                    ? 'Add a note about this place'
                                    : 'Add a note about this photo',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.multiline,
                            ),
                            if (_selectedUpdatePinId case final pinId?) ...[
                              const SizedBox(height: 8),
                              if (_selectedPinIsGone(nearbyPins, pinId))
                                const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.location_off_outlined),
                                  title: Text(
                                    'This place is already marked gone',
                                  ),
                                )
                              else
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _markSelectedPinGone,
                                  onChanged: locked
                                      ? null
                                      : (value) => setState(
                                          () => _markSelectedPinGone = value,
                                        ),
                                  title: const Text('Mark this place as gone'),
                                  subtitle: const Text(
                                    'The photo will be added before its status changes.',
                                  ),
                                  secondary: const Icon(
                                    Icons.location_off_outlined,
                                  ),
                                ),
                            ],
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
                text: _uploadedUpdatePinId != null
                    ? 'Retry mark as gone'
                    : _photoUploadRetry.pendingRequest != null
                    ? 'Retry photo update'
                    : _selectedUpdatePinId == null
                    ? 'Upload'
                    : _markSelectedPinGone
                    ? 'Update and mark gone'
                    : 'Add photo update',
                showLoadingIndicator: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nearbyPinPicker(
    List<PinEntity> nearbyPins, {
    required bool pinsLoading,
    required bool locked,
  }) {
    final location = _presencePosition;
    final canSearch =
        location != null &&
        location.accuracy.isFinite &&
        location.accuracy >= 0 &&
        location.accuracy <= 50;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: RadioGroup<String?>(
          groupValue: _selectedUpdatePinId,
          onChanged: (pinId) {
            if (!locked) _selectUpdatePin(pinId);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Add this photo to',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RadioListTile<String?>(
                value: null,
                enabled: !locked,
                title: const Text('A new pin'),
                subtitle: const Text('Create a new place in this group'),
                secondary: const Icon(Icons.add_location_alt_outlined),
              ),
              if (_checkingLocation)
                const ListTile(
                  dense: true,
                  leading: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Checking nearby pins…'),
                )
              else if (!canSearch)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_searching),
                  title: const Text('Nearby updates need a precise location'),
                  subtitle: const Text(
                    'Allow location access and try again. Pins within 50 m will appear here.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Refresh location',
                    onPressed: locked ? null : _refreshPresencePosition,
                    icon: const Icon(Icons.refresh),
                  ),
                )
              else if (pinsLoading)
                const ListTile(
                  dense: true,
                  leading: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Loading pins in this group…'),
                )
              else if (nearbyPins.isEmpty)
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.near_me_outlined),
                  title: Text('No nearby pins in this group'),
                  subtitle: Text('This photo will create a new pin.'),
                )
              else ...[
                const Divider(height: 1),
                for (final pin in nearbyPins)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Radio<String?>(value: pin.pinId),
                        const SizedBox(width: 8),
                        _NearbyPinImagePreview(pin: pin),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: locked
                                ? null
                                : () => _selectUpdatePin(pin.pinId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pin.title?.trim().isNotEmpty == true
                                        ? pin.title!.trim()
                                        : 'Untitled place',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_distanceTo(pin).round()} m away'
                                    '${pin.description?.trim().isNotEmpty == true ? ' · ${pin.description!.trim()}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PinEntity> _nearbySyncedPins(List<PinEntity> pins) {
    final position = _presencePosition;
    if (position == null) return const [];
    return pins.where((pin) => canAddPinPhotoHere(position, pin)).toList()
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
  }

  bool _selectedPinIsGone(List<PinEntity> pins, String pinId) =>
      pins.where((pin) => pin.pinId == pinId).firstOrNull?.isGone ?? false;

  void _selectUpdatePin(String? pinId) {
    setState(() {
      _selectedUpdatePinId = pinId;
      _markSelectedPinGone = false;
    });
  }

  double _distanceTo(PinEntity pin) {
    final position = _presencePosition;
    if (position == null) return double.infinity;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(position.latitude, position.longitude),
      LatLng(pin.latitude, pin.longitude),
    );
  }

  Future<void> _refreshPresencePosition() async {
    if (mounted) setState(() => _checkingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _presencePosition = position;
        _checkingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _presencePosition = null;
        _checkingLocation = false;
      });
    }
  }

  Future<void> handleApprove() async {
    if (_approvalStarted) return Future<void>.value();
    final groupId = groupIdAt(
      ref.read(groupOrderServiceProvider),
      ref.read(cameraGroupIndexProvider),
    );
    if (groupId == null) return Future<void>.value();
    _approvalStarted = true;
    if (_selectedUpdatePinId case final selectedId?) {
      final pins =
          ref.read(groupDetailsPinsProvider(groupId)).value ?? const [];
      final pin = _nearbySyncedPins(pins)
          .where((candidate) => candidate.pinId == selectedId)
          .firstOrNull;
      if (pin == null) {
        _approvalStarted = false;
        CustomErrorSnackBar.message(
          message: 'That pin is no longer nearby. Choose another pin.',
          type: CustomErrorSnackBarType.error,
        );
        return;
      }
      await _submitPhotoUpdate(pin);
      return;
    }

    await _saveNewPin(groupId);
  }

  Future<void> _submitPhotoUpdate(PinEntity pin) async {
    final position = _presencePosition;
    if (!canAddPinPhotoHere(position, pin)) {
      _approvalStarted = false;
      CustomErrorSnackBar.message(
        message:
            'A precise location within 50 m is required to update this pin.',
        type: CustomErrorSnackBarType.error,
      );
      return;
    }

    if (_uploadedUpdatePinId != pin.pinId) {
      if (_photoUploadRetry.pendingRequest == null) {
        _photoUploadRetry.prepare(
          PinPhotoRequestDto(
            image: base64Encode(widget.image),
            idempotencyKey: const Uuid().v4(),
            latitude: position!.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            caption: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          ),
        );
      }

      try {
        final uploadedPhoto = await _photoUploadRetry.submit(
          (request) => ref.read(pinApiProvider).addPinPhoto(pin.pinId, request),
        );
        try {
          await _cacheUploadedPhotoHistory(pin.pinId, uploadedPhoto);
        } catch (_) {
          // The server accepted the photo; profile cache refresh is best-effort.
        }
        if (mounted) {
          setState(() => _uploadedUpdatePinId = pin.pinId);
        } else {
          _uploadedUpdatePinId = pin.pinId;
        }
        ref.invalidate(pinPhotoHistoryProvider(pin.pinId));
        ref.invalidate(groupPinEntriesProvider(pin.groupId));
        ref.invalidate(activePinEntriesProvider);
      } on ApiException catch (error) {
        _photoUploadRetry.handleApiFailure(error);
        _approvalStarted = false;
        CustomErrorSnackBar.message(
          message: error.code == 403
              ? 'You need to be within 50 m of this pin to add a photo.'
              : 'Could not add the photo. Please try again.',
          type: CustomErrorSnackBarType.error,
        );
        return;
      } catch (_) {
        _approvalStarted = false;
        CustomErrorSnackBar.message(
          message: 'Could not add the photo. Please try again.',
          type: CustomErrorSnackBarType.error,
        );
        return;
      }
    }

    if (_markSelectedPinGone && !pin.isGone) {
      String? error;
      try {
        error = await ref.read(pinServiceProvider).setPinGone(pin.pinId, true);
      } catch (_) {
        error = 'Could not update this place.';
      }
      if (!mounted) return;
      if (error != null) {
        _approvalStarted = false;
        CustomErrorSnackBar.message(
          message: 'Photo added, but the place could not be marked gone. Tap to retry.',
          type: CustomErrorSnackBarType.error,
        );
        return;
      }
    }

    if (!mounted) return;
    ref.invalidate(groupPinEntriesProvider(pin.groupId));
    CustomErrorSnackBar.message(
      message: _markSelectedPinGone && !pin.isGone
          ? 'Photo updated and place marked gone.'
          : 'Photo update added.',
    );
    _returnToFeed();
  }

  Future<void> _cacheUploadedPhotoHistory(
    String pinId,
    PinPhotoDto? uploadedPhoto,
  ) async {
    final repository = ref.read(pinPhotoHistoryRepositoryProvider);
    if (uploadedPhoto == null) {
      final history = await ref.read(pinApiProvider).getPinPhotos(pinId);
      if (history != null) await repository.putMultiple({pinId: history});
      return;
    }

    final cachedHistory = await repository.get(pinId);
    final photosById = <String, PinPhotoDto>{
      for (final photo in cachedHistory?.photos ?? const <PinPhotoDto>[])
        photo.id: photo,
      uploadedPhoto.id: uploadedPhoto,
    };
    await repository.putMultiple({pinId: photosById.values.toList()});
  }

  Future<void> _saveNewPin(String groupId) async {
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
    // Wait for the post and image to commit to the durable local outbox. The
    // PinService starts the network upload in the background after that point.
    String? saveError;
    try {
      saveError = await ref
          .read(pinServiceProvider)
          .addPinToGroup(pin, widget.image);
    } catch (_) {
      saveError = 'Could not save post on this device. Please try again.';
    }
    if (!mounted) return;
    if (saveError != null) {
      _approvalStarted = false;
      CustomErrorSnackBar.message(
        message: 'Could not save post on this device. Please try again.',
        type: CustomErrorSnackBarType.error,
      );
      return;
    }

    if (reviewState != null) {
      unawaited(postUploadActions(reviewState));
    }
    _returnToFeed();
  }

  void _returnToFeed() {
    ref
        .read(cameraGroupIndexProvider.notifier)
        .updateIndex(_groupIndexWhenOpened);
    Navigator.of(context).popUntil((route) => route.isFirst);
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
        setState(() {
          _selectedUpdatePinId = null;
          _markSelectedPinGone = false;
          ref
              .read(cameraGroupIndexProvider.notifier)
              .updateIndex(groups.indexOf(group));
        });
      },
    );
  }
}

class _NearbyPinImagePreview extends ConsumerWidget {
  const _NearbyPinImagePreview({required this.pin});

  final PinEntity pin;

  static const _size = 62.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pinImageForDetailsProvider(pin.pinId));
    final name = pin.title?.trim().isNotEmpty == true
        ? pin.title!.trim()
        : 'Untitled place';

    return Tooltip(
      message: 'View $name details',
      child: Semantics(
        button: true,
        label: 'Preview photo for $name. Open pin details.',
        child: SizedBox.square(
          dimension: _size,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.pushNamed(
                'viewImage',
                pathParameters: {'id': pin.pinId},
              ),
              child: image.when(
                data: (bytes) => bytes == null
                    ? _placeholder(context)
                    : Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(context),
                      ),
                error: (_, _) => _placeholder(context),
                loading: () => const Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.photo_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
