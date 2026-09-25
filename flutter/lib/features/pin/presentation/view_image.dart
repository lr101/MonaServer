import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_presence_control.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
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
    final currentPin = pin.whenOrNull(data: (value) => value);
    final userPosition = ref
        .watch(currentLocationProvider)
        .whenOrNull(data: (position) => position);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    var maxWidth = screenWidth;
    var maxHeight = screenHeight * 0.7;

    if (maxWidth / maxHeight > 3 / 4) {
      maxWidth = maxHeight * 3 / 4;
    } else {
      maxHeight = maxWidth * 4 / 3;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Overview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child:
                  pin.whenOrNull(
                    data: (value) => value != null
                        ? InteractiveViewer(
                            minScale: 0.1,
                            maxScale: 5,
                            clipBehavior: Clip.none,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 9,
                              ),
                              child: SizedBox(
                                width: maxWidth,
                                child: FeedCardImage(
                                  item: value,
                                  maxHeight: maxHeight,
                                  maxWidth: maxWidth,
                                ),
                              ),
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ) ??
                  const CircularProgressIndicator(),
            ),
          ),
          if (currentPin != null)
            PinPresenceControl(
              pin: currentPin,
              userPosition: userPosition,
              isSaving: _isSavingPresence,
              onToggle: () => _updatePresence(currentPin),
            ),
        ],
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
