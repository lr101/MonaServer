import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewImage extends ConsumerStatefulWidget {
  const ViewImage({super.key, required this.pinId});

  final String pinId;

  @override
  ConsumerState<ViewImage> createState() => _ViewImageState();
}

class _ViewImageState extends ConsumerState<ViewImage> {
  bool _isSavingPresence = false;

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
          final username = ref.watch(
            userByIdUsernameProvider(currentPin.creator),
          );
          final image = ref
              .watch(pinImageBytesProvider(currentPin.pinId))
              .value;
          final photos =
              ref
                  .watch(pinPhotoHistoryProvider(currentPin.pinId))
                  .whenOrNull(data: (value) => value) ??
              const [];
          final pinTitle = currentPin.title?.trim();
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
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pinTitle == null || pinTitle.isEmpty
                            ? 'Map pin'
                            : pinTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${currentPin.latitude.toStringAsFixed(5)}, '
                              '${currentPin.longitude.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          ClickableUser(
                            userId: currentPin.creator,
                            child: Text(
                              username.value ?? 'Pin creator',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FeedCardSubtitle(pin: currentPin),
                      const SizedBox(height: 12),
                      PinPresenceControl(
                        pin: currentPin,
                        userPosition: userPosition,
                        isSaving: _isSavingPresence,
                        onToggle: () => _updatePresence(currentPin),
                      ),
                      const SizedBox(height: 8),
                      PinPhotoHistoryPanel(
                        pin: currentPin,
                        userPosition: userPosition,
                      ),
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
