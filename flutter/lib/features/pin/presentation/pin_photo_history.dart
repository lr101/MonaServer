import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openapi/api.dart';
import 'package:uuid/uuid.dart';

final pinPhotoHistoryProvider =
    FutureProvider.family<List<PinPhotoDto>, String>((ref, pinId) async {
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
  });

  final PinEntity pin;
  final Position? userPosition;
  final bool showAvailabilityMessage;

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
    final pendingRequest = _uploadRetry.pendingRequest;
    if (_isPreparingOrUploading ||
        (pendingRequest == null &&
            !canAddPinPhotoHere(widget.userPosition, widget.pin))) {
      return;
    }
    setState(() => _isPreparingOrUploading = true);
    try {
      if (pendingRequest == null) {
        final XFile? picked = await Navigator.of(context).push<XFile>(
          MaterialPageRoute(builder: (_) => const Camera(pinPhotoMode: true)),
        );
        if (!mounted || picked == null) return;
        final Uint8List? imageBytes = await CustomImagePicker.autoCrop(
          res: picked,
        );
        if (!mounted) return;
        if (imageBytes == null) {
          _showMessage('Choose a valid photo to add an update.');
          return;
        }

        final caption = await showDialog<String?>(
          context: context,
          builder: (context) => _PinPhotoComposer(imageBytes: imageBytes),
        );
        if (!mounted || caption == null) return;

        final position = widget.userPosition;
        if (!canAddPinPhotoHere(position, widget.pin)) {
          _showMessage('Move closer to the pin and try again.');
          return;
        }
        _uploadRetry.prepare(
          PinPhotoRequestDto(
            image: base64Encode(imageBytes),
            idempotencyKey: const Uuid().v4(),
            latitude: position!.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            caption: caption.isEmpty ? null : caption,
          ),
        );
      }

      await _uploadRetry.submit(
        (request) =>
            ref.read(pinApiProvider).addPinPhoto(widget.pin.pinId, request),
      );
      if (!mounted) return;
      ref.invalidate(pinPhotoHistoryProvider(widget.pin.pinId));
      _showMessage('Photo update added.');
    } on ApiException catch (error) {
      _uploadRetry.handleApiFailure(error);
      if (!mounted) return;
      _showMessage(
        error.code == 403
            ? 'You need to be within 50 m of this pin to add a photo.'
            : 'Could not add the photo. Please try again.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not add the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isPreparingOrUploading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PinPhotoComposer extends StatefulWidget {
  const _PinPhotoComposer({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_PinPhotoComposer> createState() => _PinPhotoComposerState();
}

class _PinPhotoComposerState extends State<_PinPhotoComposer> {
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add photo update'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              widget.imageBytes,
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _captionController,
            maxLength: 280,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Add a note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.of(context).pop(_captionController.text.trim()),
        child: const Text('Share update'),
      ),
    ],
  );
}
