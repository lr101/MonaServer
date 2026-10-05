import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openapi/api.dart';

final pinPhotoHistoryProvider =
    FutureProvider.family<List<PinPhotoDto>, String>((ref, pinId) async {
      // Image URLs are signed for a limited time. Refresh while a detail or
      // entry list is still listening so displayed images remain available.
      final expiry = Timer(const Duration(minutes: 45), ref.invalidateSelf);
      ref.onDispose(expiry.cancel);
      final photos = await ref.watch(pinApiProvider).getPinPhotos(pinId);
      return photos ?? const [];
    });

bool canAddPinPhotoHere(Position? userPosition, PinEntity pin) {
  return pin.lastSynced != null &&
      userPosition != null &&
      userPosition.accuracy.isFinite &&
      userPosition.accuracy >= 0 &&
      userPosition.accuracy <= 50 &&
      isPinWithinPresenceRange(userPosition, pin);
}

class PinPhotoUploadRetry {
  PinPhotoRequestDto? _pendingRequest;

  PinPhotoRequestDto? get pendingRequest => _pendingRequest;

  PinPhotoRequestDto prepare(PinPhotoRequestDto request) =>
      _pendingRequest ??= request;

  void handleApiFailure(ApiException error) {
    if (!isAmbiguousPinPhotoFailure(error)) clear();
  }

  void clear() => _pendingRequest = null;

  Future<PinPhotoDto?> submit(
    Future<PinPhotoDto?> Function(PinPhotoRequestDto request) send,
  ) async {
    final request = _pendingRequest;
    if (request == null) {
      throw StateError('No pin photo upload is pending.');
    }
    final response = await send(request);
    _pendingRequest = null;
    return response;
  }
}

bool isAmbiguousPinPhotoFailure(ApiException error) =>
    error.code == 408 || error.code >= 500 || error.innerException != null;

class PinPhotoHistoryPanel extends ConsumerStatefulWidget {
  const PinPhotoHistoryPanel({
    super.key,
    required this.pin,
    required this.userPosition,
    this.showAvailabilityMessage = true,
    this.iconOnly = false,
    this.onPhotoAdded,
  });

  final PinEntity pin;
  final Position? userPosition;
  final bool showAvailabilityMessage;
  final bool iconOnly;
  final VoidCallback? onPhotoAdded;

  @override
  ConsumerState<PinPhotoHistoryPanel> createState() =>
      _PinPhotoHistoryPanelState();
}

class _PinPhotoHistoryPanelState extends ConsumerState<PinPhotoHistoryPanel> {
  bool _isPreparingOrUploading = false;
  final _uploadRetry = PinPhotoUploadRetry();

  @override
  void didUpdateWidget(covariant PinPhotoHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin.pinId != widget.pin.pinId) {
      _uploadRetry.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(pinPhotoHistoryProvider(widget.pin.pinId));
    final nearby = isPinWithinPresenceRange(widget.userPosition, widget.pin);
    final locationIsAccurate =
        widget.userPosition != null &&
        widget.userPosition!.accuracy.isFinite &&
        widget.userPosition!.accuracy >= 0 &&
        widget.userPosition!.accuracy <= 50;
    final canAdd = canAddPinPhotoHere(widget.userPosition, widget.pin);
    final retryPending = _uploadRetry.pendingRequest != null;

    if (widget.iconOnly)
      return IconButton(
        tooltip: retryPending
            ? 'Retry photo update'
            : history.hasError
            ? 'Retry photo history'
            : canAdd
            ? 'Add photo update'
            : 'Add photo update · ${_availabilityMessage(synced: widget.pin.lastSynced != null, nearby: nearby, locationIsAccurate: locationIsAccurate)}',
        onPressed: _isPreparingOrUploading
            ? null
            : retryPending
            ? _addPhoto
            : history.hasError
            ? () => ref.invalidate(pinPhotoHistoryProvider(widget.pin.pinId))
            : canAdd
            ? _addPhoto
            : null,
        icon: _isPreparingOrUploading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                retryPending || history.hasError
                    ? Icons.refresh_rounded
                    : Icons.add_a_photo_outlined,
              ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (retryPending)
          OutlinedButton.icon(
            onPressed: _isPreparingOrUploading ? null : _addPhoto,
            icon: _isPreparingOrUploading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              _isPreparingOrUploading
                  ? 'Retrying photo update…'
                  : 'Retry photo update',
            ),
          )
        else
          FilledButton.icon(
            onPressed: canAdd && !_isPreparingOrUploading ? _addPhoto : null,
            icon: _isPreparingOrUploading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: const Text('Update'),
          ),
        if (widget.showAvailabilityMessage && !retryPending && !canAdd) ...[
          const SizedBox(height: 4),
          Text(
            _availabilityMessage(
              synced: widget.pin.lastSynced != null,
              nearby: nearby,
              locationIsAccurate: locationIsAccurate,
            ),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (history.hasError) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Photo history unavailable',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(pinPhotoHistoryProvider(widget.pin.pinId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _availabilityMessage({
    required bool synced,
    required bool nearby,
    required bool locationIsAccurate,
  }) {
    if (!synced) return 'Sync this pin before adding a photo.';
    if (widget.userPosition == null) return 'Waiting for a location fix.';
    if (!locationIsAccurate) {
      return 'Location accuracy must be 50 m or better.';
    }
    if (!nearby) return 'Get within 50 m of this pin to add a photo.';
    return 'Add a photo to show what this place looks like now.';
  }

  Future<void> _addPhoto() async {
    if (_isPreparingOrUploading ||
        !canAddPinPhotoHere(widget.userPosition, widget.pin))
      return;
    setState(() => _isPreparingOrUploading = true);
    try {
      final groups = ref.read(groupOrderServiceProvider);
      final groupIndex = groups.indexOf(widget.pin.groupId);
      if (groupIndex >= 0) {
        ref.read(cameraGroupIndexProvider.notifier).updateIndex(groupIndex);
      }
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const Camera()));
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not open the camera. Please try again.');
    } finally {
      if (mounted) setState(() => _isPreparingOrUploading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
