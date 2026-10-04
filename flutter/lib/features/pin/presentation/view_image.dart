import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/platform/pin_photo_saver.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

class ViewImage extends ConsumerStatefulWidget {
  const ViewImage({super.key, required this.pinId});

  final String pinId;

  @override
  ConsumerState<ViewImage> createState() => _ViewImageState();
}

class _ViewImageState extends ConsumerState<ViewImage> {
  bool _isSavingPresence = false;
  bool _isDownloadingPhoto = false;
  int _selectedPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinByIdProvider(widget.pinId));
    final userPosition = ref
        .watch(currentLocationProvider)
        .whenOrNull(data: (position) => position);
    final toolbarPin = pin.whenOrNull(data: (value) => value);
    final currentUserId = ref.watch(userIdProvider);
    final creatorNameState = toolbarPin == null
        ? null
        : ref.watch(userByIdUsernameProvider(toolbarPin.creator));
    final imageState = toolbarPin == null
        ? null
        : ref.watch(pinImageForDetailsProvider(toolbarPin.pinId));
    final photoHistoryState = toolbarPin == null
        ? null
        : ref.watch(pinPhotoHistoryProvider(toolbarPin.pinId));
    final image = imageState?.value;
    final photos = photoHistoryState?.value ?? const <PinPhotoDto>[];
    final updates = photos.where((photo) => !photo.isOriginal).toList();
    final selectedUpdate =
        _selectedPhotoIndex > 0 && _selectedPhotoIndex <= updates.length
        ? updates[_selectedPhotoIndex - 1]
        : null;
    final originalPhoto = photos.where((photo) => photo.isOriginal).firstOrNull;
    final selectedPhoto = selectedUpdate ?? originalPhoto;
    final isOriginalSelected = selectedUpdate == null;
    final originalContributorId = selectedPhoto?.contributorId;
    final selectedPhotoContributor = isOriginalSelected
        ? originalContributorId == null || originalContributorId.isEmpty
              ? toolbarPin?.creator
              : originalContributorId
        : selectedPhoto?.contributorId;
    final hasSelectedPhotoBytes = isOriginalSelected
        ? image?.isNotEmpty == true || selectedPhoto?.image?.isNotEmpty == true
        : selectedPhoto?.image?.isNotEmpty == true;
    final canDownloadSelectedPhoto =
        supportsPinPhotoDownload &&
        currentUserId.isNotEmpty &&
        currentUserId == selectedPhotoContributor &&
        hasSelectedPhotoBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin details'),
        actions: [
          if (toolbarPin != null)
            PopUpMenuFeed(
              pinDto: toolbarPin,
              onDownloadPhoto: canDownloadSelectedPhoto
                  ? () => _downloadPhoto(
                      pinId: toolbarPin.pinId,
                      pinCreatorId: toolbarPin.creator,
                      photo: selectedPhoto,
                      isOriginal: isOriginalSelected,
                      originalImage: image,
                    )
                  : null,
              isDownloadingPhoto: _isDownloadingPhoto,
              tooltip: 'Pin options',
            ),
        ],
      ),
      body: pin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this pin.')),
        data: (currentPin) {
          if (currentPin == null) {
            return const Center(child: Text('This pin is unavailable.'));
          }
          final updateEnabled = canAddPinPhotoHere(userPosition, currentPin);
          final presenceEnabled =
              currentPin.lastSynced != null &&
              isPinWithinPresenceRange(userPosition, currentPin);
          final availabilityMessage = _availabilityMessage(
            pin: currentPin,
            userPosition: userPosition,
            updateEnabled: updateEnabled,
            presenceEnabled: presenceEnabled,
          );
          final title = currentPin.title?.trim();
          final description = currentPin.description?.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onDoubleTap: () {
                          final userId = ref
                              .read(globalDataServiceProvider)
                              .userId;
                          if (userId == null) return;
                          ref
                              .read(
                                likeServiceProvider(currentPin.pinId).notifier,
                              )
                              .addLike(
                                currentPin.creator,
                                CreateLikeDto(userId: userId, like: true),
                              );
                        },
                        child: PinPhotoCarousel(
                          key: ValueKey(currentPin.pinId),
                          originalImage: image,
                          photos: photos,
                          isOriginalLoading:
                              (imageState?.isLoading ?? false) ||
                              (photoHistoryState?.isLoading ?? false),
                          onPageChanged: (index) {
                            if (_selectedPhotoIndex != index) {
                              setState(() => _selectedPhotoIndex = index);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 5),
                      FeedCardSubtitle(pin: currentPin, showDescription: false),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _selectedPhotoDetails(
                          key: ValueKey(selectedPhoto?.id ?? 'original'),
                          photo: selectedPhoto,
                          isOriginal: isOriginalSelected,
                          title: title == null || title.isEmpty ? null : title,
                          description:
                              description == null || description.isEmpty
                              ? null
                              : description,
                          creatorId: currentPin.creator,
                          creatorName: creatorNameState?.value ?? 'Pin creator',
                          pin: currentPin,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PinPresenceControl(
                              pin: currentPin,
                              userPosition: userPosition,
                              isSaving: _isSavingPresence,
                              showStatusMessage: false,
                              onToggle: () => _updatePresence(currentPin),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PinPhotoHistoryPanel(
                              pin: currentPin,
                              userPosition: userPosition,
                              showAvailabilityMessage: false,
                            ),
                          ),
                        ],
                      ),
                      if (availabilityMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          availabilityMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _selectedPhotoDetails({
    required Key key,
    required PinPhotoDto? photo,
    required bool isOriginal,
    required String? title,
    required String? description,
    required String creatorId,
    required String creatorName,
    required PinEntity pin,
  }) {
    final date = photo?.observedAt ?? pin.creationDate;
    final author = photo?.contributorUsername ?? creatorName;
    final authorText = Text(
      author,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final contributorId = photo?.contributorId;
    final Widget authorWidget;
    if (isOriginal) {
      authorWidget = ClickableUser(
        userId: contributorId ?? creatorId,
        child: authorText,
      );
    } else if (contributorId != null && contributorId.isNotEmpty) {
      authorWidget = ClickableUser(userId: contributorId, child: authorText);
    } else {
      authorWidget = authorText;
    }
    final dateLabel = MaterialLocalizations.of(context)
        .formatMediumDate(date.toLocal());
    final detailsText = photo?.caption?.trim();
    final body = isOriginal ? description : detailsText;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOriginal && title != null)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(child: authorWidget),
            const SizedBox(width: 6),
            Text(
              '· $dateLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (body != null && body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }

  Future<void> _downloadPhoto({
    required String pinId,
    required String pinCreatorId,
    required PinPhotoDto? photo,
    required bool isOriginal,
    required Uint8List? originalImage,
  }) async {
    if (_isDownloadingPhoto) return;
    setState(() => _isDownloadingPhoto = true);
    _showMessage('Downloading photo…', duration: const Duration(seconds: 25));
    try {
      final bytes = await _loadPhotoBytes(
        photo: photo,
        pinId: pinId,
        pinCreatorId: pinCreatorId,
        isOriginal: isOriginal,
        originalImage: originalImage,
      );
      final name = _photoFileName(pinId, photo?.id ?? 'original');
      await savePinPhoto(bytes, name: name);
      if (mounted) _showMessage('Photo saved to your device.');
    } on _PinPhotoDownloadException {
      if (mounted) {
        _showMessage('Could not download this photo. Check your connection.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not save this photo. Check photo access and device storage.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPhoto = false);
    }
  }

  Future<Uint8List> _loadPhotoBytes({
    required String pinId,
    required String pinCreatorId,
    required PinPhotoDto? photo,
    required bool isOriginal,
    required Uint8List? originalImage,
  }) async {
    if (isOriginal) {
      final bytes = originalImage;
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    var photoToDownload = photo;
    if (photo != null) {
      try {
        final photos = await ref
            .read(pinApiProvider)
            .getPinPhotos(pinId)
            .timeout(const Duration(seconds: 20));
        photoToDownload = photos
            ?.where(
              (candidate) =>
                  candidate.id == photo.id &&
                  candidate.pinId == pinId &&
                  candidate.isOriginal == isOriginal,
            )
            .firstOrNull;
        if (photoToDownload == null) {
          throw const _PinPhotoDownloadException();
        }

        final contributorId = photoToDownload.contributorId;
        final ownerId =
            isOriginal && (contributorId == null || contributorId.isEmpty)
            ? pinCreatorId
            : contributorId;
        final currentUserId = ref.read(userIdProvider);
        if (currentUserId.isEmpty || currentUserId != ownerId) {
          throw const _PinPhotoDownloadException();
        }
      } on _PinPhotoDownloadException {
        rethrow;
      } catch (_) {
        throw const _PinPhotoDownloadException();
      }
    }

    final imageUrl = photoToDownload?.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const _PinPhotoDownloadException();
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const _PinPhotoDownloadException();
    }
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw const _PinPhotoDownloadException();
      }
      return response.bodyBytes;
    } on _PinPhotoDownloadException {
      rethrow;
    } catch (_) {
      throw const _PinPhotoDownloadException();
    }
  }

  String _photoFileName(String pinId, String photoId) {
    final safePinId = pinId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final safePhotoId = photoId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'stick-it-$safePinId-$safePhotoId';
  }

  void _showMessage(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  String? _availabilityMessage({
    required PinEntity pin,
    required Position? userPosition,
    required bool updateEnabled,
    required bool presenceEnabled,
  }) {
    if (updateEnabled && presenceEnabled) return null;
    if (pin.lastSynced == null) return 'Sync this pin before updating it.';
    if (userPosition == null) return 'Waiting for a location fix.';
    if (!isPinWithinPresenceRange(userPosition, pin)) {
      return 'Get within 50 m of this pin to update it.';
    }
    if (!updateEnabled) {
      return 'Location accuracy must be 50 m or better to add a photo update.';
    }
    return null;
  }

  Future<void> _updatePresence(PinEntity pin) async {
    setState(() => _isSavingPresence = true);
    try {
      final error = await ref
          .read(pinServiceProvider)
          .setPinGone(pin.pinId, !pin.isGone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? (pin.isGone ? 'Marked still here' : 'Marked gone'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPresence = false);
    }
  }
}

class _PinPhotoDownloadException implements Exception {
  const _PinPhotoDownloadException();
}
