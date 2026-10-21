import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image_header.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_description.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/remote_pin_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';

class FeedCardImage extends ConsumerStatefulWidget {
  const FeedCardImage({
    super.key,
    required this.item,
    required this.maxHeight,
    required this.maxWidth,
    this.distance,
    this.rotateHeader = false,
    this.onTab,
    this.initialPhotoId,
    this.onPhotoChanged,
    this.isDetail = false,
  });
  final PinEntity item;
  final double maxWidth;
  final double maxHeight;
  final double? distance;
  final bool rotateHeader;
  final dynamic Function(LatLng location, double zoom)? onTab;
  final String? initialPhotoId;
  final ValueChanged<PinEntity>? onPhotoChanged;
  final bool isDetail;
  @override
  ConsumerState<FeedCardImage> createState() => _FeedCardImageState();
}

class _FeedCardImageState extends ConsumerState<FeedCardImage> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant FeedCardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.entryId != widget.item.entryId ||
        oldWidget.initialPhotoId != widget.initialPhotoId) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.item.isPhotoUpdate
        ? ref.watch(pinByIdProvider(widget.item.pinId)).value ?? widget.item
        : widget.item;
    final history = ref.watch(pinPhotoHistoryProvider(parent.pinId));
    final photos = [...?history.value];
    if (widget.item.isPhotoUpdate &&
        !photos.any((p) => p.id == widget.item.photoId)) {
      photos.add(
        PinPhotoDto(
          id: widget.item.photoId!,
          pinId: parent.pinId,
          contributorId: widget.item.creator.isEmpty
              ? null
              : widget.item.creator,
          contributorUsername: widget.item.contributorUsername ?? 'Former user',
          observedAt: widget.item.creationDate,
          image: widget.item.photoUrl,
          imageThumbnail: widget.item.photoThumbnailUrl,
          imageBlurhash: widget.item.imageBlurhash,
          caption: widget.item.description,
          isOriginal: false,
        ),
      );
    }
    final originalPhoto = photos.where((photo) => photo.isOriginal).firstOrNull;
    final updates = photos.where((p) => !p.isOriginal).toList();
    final initialId = widget.initialPhotoId ?? widget.item.photoId;
    final selectedPhoto = _selectedIndex == null
        ? photos.where((p) => p.id == initialId).firstOrNull
        : _selectedIndex == 0
        ? photos.where((p) => p.isOriginal).firstOrNull
        : _selectedIndex! <= updates.length
        ? updates[_selectedIndex! - 1]
        : null;
    var selected = selectedPhoto != null && !selectedPhoto.isOriginal
        ? parent.withPhotoUpdate(selectedPhoto)
        : parent;
    if (_selectedIndex == null &&
        selectedPhoto == null &&
        widget.item.isPhotoUpdate) {
      selected = widget.item;
    }

    final showPhoto = ref.watch(feedMapStateProvider(widget.item.entryId));
    final overlayTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(),
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    );
    void openDetails() => context.pushNamed(
      'viewImage',
      pathParameters: {'id': parent.pinId},
      queryParameters: {
        if (selected.photoId != null) 'photo': selected.photoId,
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: widget.maxWidth,
          height: widget.maxHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PinPhotoCarousel(
              key: ValueKey(widget.item.entryId),
              pinId: parent.pinId,
              originalImageBlurhash:
                  parent.imageBlurhash ?? originalPhoto?.imageBlurhash,

              photos: photos,
              initialPhotoId: initialId,
              onPageChanged: (index) => _selectPhoto(index, parent, updates),
              onTap: widget.isDetail ? null : openDetails,
              onDoubleTap: () => _like(selected),
              overlayBuilder: (context, index, count, _, _) => Stack(
                children: [
                  if (!showPhoto) ...[
                    Positioned.fill(
                      child: ref.watch(feedMapBuilderProvider)(widget.item),
                    ),
                  ],
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Theme(
                      data: overlayTheme,
                      child: Material(
                        color: Colors.black.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FeedCardImageHeader(
                            pin: selected,
                            distance: widget.distance,
                            showOptions: !widget.isDetail,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showPhoto && count > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: _PhotoProgressDots(index: index, count: count),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: SizedBox.square(
                      dimension: 88,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: InkWell(
                            onTap: () => ref
                                .read(
                                  feedMapStateProvider(widget.item.entryId)
                                      .notifier,
                                )
                                .update(),
                            child: showPhoto
                                ? Semantics(
                                    button: true,
                                    label: 'Show map',
                                    child: ref.watch(feedMapBuilderProvider)(
                                      widget.item,
                                    ),
                                  )
                                : Tooltip(
                                    message: 'Show photo',
                                    child: RemotePinImage(
                                      pinId: parent.pinId,
                                      photoId: selected.photoId,
                                      thumbnailUrl:
                                          selected.photoThumbnailUrl ??
                                          originalPhoto?.imageThumbnail,
                                      imageUrl:
                                          selected.photoUrl ??
                                          originalPhoto?.image,
                                      blurhash: selected.imageBlurhash,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FeedCardSubtitle(
          pin: selected,
          showDescription: false,
          animateLikeChanges: false,
        ),
        if (selected.title?.trim().isNotEmpty ?? false)
          Text(
            selected.title!.trim(),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (selected.description?.trim().isNotEmpty ?? false)
          FeedDescriptionExpandable(pin: selected),
      ],
    );
  }

  void _selectPhoto(int index, PinEntity parent, List<PinPhotoDto> updates) {
    setState(() => _selectedIndex = index);
    final selectedPhoto = index == 0 || index > updates.length
        ? null
        : updates[index - 1];
    widget.onPhotoChanged?.call(
      selectedPhoto == null ? parent : parent.withPhotoUpdate(selectedPhoto),
    );
  }

  void _like(PinEntity selected) {
    final userId = ref.read(globalDataServiceProvider).userId;
    if (userId != null) {
      ref
          .read(likeServiceProvider(selected.entryId).notifier)
          .addLike(selected.creator, CreateLikeDto(userId: userId, like: true));
    }
  }
}

class _PhotoProgressDots extends StatefulWidget {
  const _PhotoProgressDots({required this.index, required this.count});

  static const _maximumVisibleDots = 10;
  static const _dotSlotWidth = 9.0;
  static const _selectedExtraWidth = 7.0;

  final int index;
  final int count;

  @override
  State<_PhotoProgressDots> createState() => _PhotoProgressDotsState();
}

class _PhotoProgressDotsState extends State<_PhotoProgressDots> {
  late int _previousFirstVisibleIndex;
  late int _previousVisibleCount;
  var _hasPreviousWindow = false;
  var _entryDirection = 1;

  @override
  void initState() {
    super.initState();
    _previousFirstVisibleIndex = _firstVisibleIndex(widget.index, widget.count);
    _previousVisibleCount = _visibleCount(widget.count);
  }

  @override
  void didUpdateWidget(covariant _PhotoProgressDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousFirstVisibleIndex = _firstVisibleIndex(
      oldWidget.index,
      oldWidget.count,
    );
    _previousVisibleCount = _visibleCount(oldWidget.count);
    _hasPreviousWindow = true;

    final nextFirstVisibleIndex = _firstVisibleIndex(
      widget.index,
      widget.count,
    );
    if (nextFirstVisibleIndex > _previousFirstVisibleIndex) {
      _entryDirection = 1;
    } else if (nextFirstVisibleIndex < _previousFirstVisibleIndex) {
      _entryDirection = -1;
    } else {
      _entryDirection = widget.index >= oldWidget.index ? 1 : -1;
    }
  }

  static int _visibleCount(int count) =>
      count < _PhotoProgressDots._maximumVisibleDots
      ? count
      : _PhotoProgressDots._maximumVisibleDots;

  static int _firstVisibleIndex(int index, int count) {
    final visibleCount = _visibleCount(count);
    if (visibleCount == 0 || index < visibleCount) return 0;
    final maximumStart = count - visibleCount;
    final firstVisibleIndex = index - visibleCount + 1;
    return firstVisibleIndex > maximumStart ? maximumStart : firstVisibleIndex;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = _visibleCount(widget.count);
    final firstVisibleIndex = _firstVisibleIndex(widget.index, widget.count);
    final lastVisibleIndex = firstVisibleIndex + visibleCount - 1;
    final farthestDistance =
        (widget.index - firstVisibleIndex) > (lastVisibleIndex - widget.index)
        ? widget.index - firstVisibleIndex
        : lastVisibleIndex - widget.index;

    return Semantics(
      label: 'Photo ${widget.index + 1} of ${widget.count}',
      child: ExcludeSemantics(
        child: SizedBox(
          width:
              visibleCount * _PhotoProgressDots._dotSlotWidth +
              (visibleCount > 0 ? _PhotoProgressDots._selectedExtraWidth : 0),
          height: 9,
          child: ClipRect(
            child: Stack(
              children: [
                for (var slot = 0; slot < visibleCount; slot++) ...[
                  _positionedDot(
                    slot: slot,
                    dotIndex: firstVisibleIndex + slot,
                    farthestDistance: farthestDistance,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedDot({
    required int slot,
    required int dotIndex,
    required int farthestDistance,
  }) {
    final wasVisible =
        _hasPreviousWindow &&
        dotIndex >= _previousFirstVisibleIndex &&
        dotIndex < _previousFirstVisibleIndex + _previousVisibleCount;

    final slotWidth =
        _PhotoProgressDots._dotSlotWidth +
        (dotIndex == widget.index ? _PhotoProgressDots._selectedExtraWidth : 0);
    return AnimatedPositioned(
      key: ValueKey(dotIndex),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      // Reserve the pill's extra width before laying out its neighbors.
      left:
          slot * _PhotoProgressDots._dotSlotWidth +
          (dotIndex > widget.index
              ? _PhotoProgressDots._selectedExtraWidth
              : 0),
      top: 2,
      width: slotWidth,
      height: 5,
      child: _PhotoDotEntrance(
        animate: _hasPreviousWindow && !wasVisible,
        direction: _entryDirection,
        width: slotWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _dot(dotIndex, farthestDistance),
        ),
      ),
    );
  }

  Widget _dot(int dotIndex, int farthestDistance) {
    final isSelected = dotIndex == widget.index;
    final distance = (dotIndex - widget.index).abs();
    final opacity = isSelected || farthestDistance == 0
        ? 1.0
        : 1 - .72 * distance / farthestDistance;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: isSelected ? 12 : 5,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSelected ? 1 : .55),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
    );
  }
}

class _PhotoDotEntrance extends StatefulWidget {
  const _PhotoDotEntrance({
    required this.animate,
    required this.direction,
    required this.width,
    required this.child,
  });

  final bool animate;
  final int direction;
  final double width;
  final Widget child;

  @override
  State<_PhotoDotEntrance> createState() => _PhotoDotEntranceState();
}

class _PhotoDotEntranceState extends State<_PhotoDotEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.animate ? 0 : 1,
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: SizedBox(width: widget.width, height: 5, child: widget.child),
    builder: (context, child) => Opacity(
      opacity: _controller.value,
      child: Transform.translate(
        offset: Offset(
          widget.direction * (1 - _controller.value) * widget.width,
          0,
        ),
        child: child,
      ),
    ),
  );
}
