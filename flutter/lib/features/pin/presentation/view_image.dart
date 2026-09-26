import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_button_animated.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openapi/api.dart';

class ViewImage extends ConsumerStatefulWidget {
  const ViewImage({super.key, required this.pinId});

  final String pinId;

  @override
  ConsumerState<ViewImage> createState() => _ViewImageState();
}

class _ViewImageState extends ConsumerState<ViewImage> {
  bool _isSavingPresence = false;
  int _selectedPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinByIdProvider(widget.pinId));
    final userPosition = ref
        .watch(currentLocationProvider)
        .whenOrNull(data: (position) => position);
    final toolbarPin = pin.whenOrNull(data: (value) => value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin details'),
        actions: [if (toolbarPin != null) PopUpMenuFeed(pinDto: toolbarPin)],
      ),
      body: pin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this pin.')),
        data: (currentPin) {
          if (currentPin == null) {
            return const Center(child: Text('This pin is unavailable.'));
          }
          final creatorName = ref.watch(
            userByIdUsernameProvider(currentPin.creator),
          );
          final image = ref
              .watch(pinImageBytesProvider(currentPin.pinId))
              .value;
          final photos =
              ref
                  .watch(pinPhotoHistoryProvider(currentPin.pinId))
                  .whenOrNull(data: (value) => value) ??
              const <PinPhotoDto>[];
          final updates = photos.where((photo) => !photo.isOriginal).toList();
          final selectedUpdate =
              _selectedPhotoIndex > 0 && _selectedPhotoIndex <= updates.length
              ? updates[_selectedPhotoIndex - 1]
              : null;
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
                      PinPhotoCarousel(
                        key: ValueKey(currentPin.pinId),
                        originalImage: image,
                        photos: photos,
                        onPageChanged: (index) {
                          if (_selectedPhotoIndex != index) {
                            setState(() => _selectedPhotoIndex = index);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _selectedPhotoDetails(
                          key: ValueKey(selectedUpdate?.id ?? 'original'),
                          photo: selectedUpdate,
                          title: title == null || title.isEmpty ? null : title,
                          description:
                              description == null || description.isEmpty
                              ? null
                              : description,
                          creatorId: currentPin.creator,
                          creatorName: creatorName.value ?? 'Pin creator',
                          pin: currentPin,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PinLikeButton(pin: currentPin),
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
    required String? title,
    required String? description,
    required String creatorId,
    required String creatorName,
    required PinEntity pin,
  }) {
    final date = photo?.observedAt ?? pin.creationDate;
    final author = photo?.contributorUsername ?? creatorName;
    final authorId = photo?.contributorId ?? creatorId;
    final dateLabel = MaterialLocalizations.of(context)
        .formatMediumDate(date.toLocal());
    final detailsText = photo?.caption?.trim();
    final body = photo == null ? description : detailsText;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo == null && title != null)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (photo != null)
          Text(
            'Update',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            ClickableUser(
              userId: authorId,
              child: Text(author, style: Theme.of(context).textTheme.bodySmall),
            ),
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

class _PinLikeButton extends ConsumerWidget {
  const _PinLikeButton({required this.pin});

  final PinEntity pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final like = ref.watch(likeServiceProvider(pin.pinId));
    final liked = like.value?.likedByUser ?? false;
    final userId = ref.watch(
      globalDataServiceProvider.select((data) => data.userId),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: '${like.value?.likeCount ?? 0} likes',
        child: LikeButtonAnimated(
          isLikedProvider: likeServiceProvider(pin.pinId)
              .select((state) => state.value?.likedByUser),
          isLiked: liked,
          size: 28,
          likeCount: like.value?.likeCount ?? 0,
          likeBuilder: (isLiked) => Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked
                ? Colors.red
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          onTap: userId == null
              ? null
              : (isLiked) async {
                  try {
                    await ref
                        .read(likeServiceProvider(pin.pinId).notifier)
                        .addLike(
                          pin.creator,
                          CreateLikeDto(userId: userId, like: !isLiked),
                        );
                    return true;
                  } catch (_) {
                    return false;
                  }
                },
        ),
      ),
    );
  }
}
