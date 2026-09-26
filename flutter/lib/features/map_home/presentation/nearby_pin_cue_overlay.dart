import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/map_home/data/nearby_pin_cue.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NearbyPinCueOverlay extends ConsumerStatefulWidget {
  const NearbyPinCueOverlay({
    super.key,
    required this.isActive,
    required this.onOpenPin,
  });

  final bool isActive;
  final ValueChanged<String> onOpenPin;

  @override
  ConsumerState<NearbyPinCueOverlay> createState() =>
      _NearbyPinCueOverlayState();
}

class _NearbyPinCueOverlayState extends ConsumerState<NearbyPinCueOverlay>
    with WidgetsBindingObserver {
  String? _locallyDismissedKey;
  String? _sessionUserId;
  final Set<String> _openedPinIds = {};
  late AppLifecycleState _lifecycleState;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _lifecycleState = binding.lifecycleState ?? AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == _lifecycleState) return;
    setState(() => _lifecycleState = state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(userIdProvider);
    if (_sessionUserId != userId) {
      _sessionUserId = userId;
      _openedPinIds.clear();
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isForegroundMap =
        widget.isActive &&
        _lifecycleState == AppLifecycleState.resumed &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final today = _dateStamp(DateTime.now());
    final dismissalKey = 'nearbyPinCueDismissed:$userId';
    final locallyDismissedKey = '$dismissalKey:$today';
    final nearbyState = isForegroundMap
        ? ref.watch(nearbyPinCandidatesProvider)
        : const AsyncData<List<NearbyPinDto>>([]);
    final candidates = nearbyState.hasError
        ? const <NearbyPinDto>[]
        : nearbyState.value ?? const <NearbyPinDto>[];
    final dismissedToday =
        preferences.getString(dismissalKey) == today ||
        _locallyDismissedKey == locallyDismissedKey;
    NearbyPinDto? nearest;
    if (!dismissedToday) {
      for (final candidate in candidates) {
        if (!_openedPinIds.contains(candidate.pin.id)) {
          nearest = candidate;
          break;
        }
      }
    }
    final nearestPin = nearest;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            if (reduceMotion) return child;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              ),
            );
          },
          child: nearestPin == null
              ? const SizedBox.shrink(key: ValueKey('no-nearby-pin'))
              : NearbyPinCueCard(
                  key: ValueKey(nearestPin.pin.id),
                  nearbyPin: nearestPin,
                  onTap: () => _openPin(nearestPin.pin.id),
                  onDismiss: () => _dismissForToday(
                    preferences,
                    dismissalKey,
                    locallyDismissedKey,
                    today,
                  ),
                ),
        ),
      ),
    );
  }

  void _openPin(String pinId) {
    setState(() => _openedPinIds.add(pinId));
    widget.onOpenPin(pinId);
  }

  Future<void> _dismissForToday(
    SharedPreferences preferences,
    String dismissalKey,
    String locallyDismissedKey,
    String today,
  ) async {
    setState(() => _locallyDismissedKey = locallyDismissedKey);
    try {
      await preferences.setString(dismissalKey, today);
    } catch (_) {
      // The local dismissal still prevents the cue from interrupting this
      // session if the preference store is temporarily unavailable.
    }
  }
}

class NearbyPinCueCard extends ConsumerWidget {
  const NearbyPinCueCard({
    super.key,
    required this.nearbyPin,
    required this.onTap,
    required this.onDismiss,
  });

  final NearbyPinDto nearbyPin;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pin = nearbyPin.pin;
    final group = ref.watch(groupMetadataProvider(pin.groupId)).value;
    final groupImage =
        ref.watch(groupPinImageByIdProvider(pin.groupId)).value ??
        ref.watch(defaultGroupPinImageProvider);
    final isGone = pin.isGone ?? false;
    final distance = _distanceLabel(nearbyPin.distanceMeters);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: isGone
                  ? 'Open historical pin in ${nearbyPin.groupName}, $distance away'
                  : 'Open nearby pin in ${nearbyPin.groupName}, $distance away',
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 38,
                        child: PinMarkerImage(
                          isGone: isGone,
                          style: group?.pinStyle ?? 'classic',
                          image: Image.memory(groupImage!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGone ? 'Historical pin nearby' : 'Pin nearby',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nearbyPin.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  isGone
                                      ? Icons.history
                                      : Icons.near_me_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isGone
                                      ? 'Marked gone · $distance'
                                      : '$distance away',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Latest pin photo',
                        image: true,
                        child: _PinPhotoThumbnail(
                          imageUrl: pin.image,
                          isGone: isGone,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss nearby pin for today',
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _PinPhotoThumbnail extends StatelessWidget {
  const _PinPhotoThumbnail({
    required this.imageUrl,
    required this.isGone,
    required this.color,
  });

  final String? imageUrl;
  final bool isGone;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl == null || imageUrl!.isEmpty) {
      image = Icon(
        Icons.photo_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    } else {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }

    if (isGone && imageUrl != null && imageUrl!.isNotEmpty) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: ColoredBox(
        color: color,
        child: SizedBox.square(dimension: 52, child: image),
      ),
    );
  }
}

String _distanceLabel(int meters) =>
    meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';

String _dateStamp(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
