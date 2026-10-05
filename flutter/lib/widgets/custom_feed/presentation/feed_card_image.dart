import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image_header.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_description.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
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
          caption: widget.item.description,
          isOriginal: false,
        ),
      );
    }
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

    final preview = ref.watch(pinThumbnailBytesProvider(parent.pinId));
    final image = ref.watch(pinImageForDetailsProvider(parent.pinId));
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
              originalImage: image.value ?? preview.value,
              isOriginalLoading:
                  (image.isLoading && preview.isLoading) || history.isLoading,
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
                                    child: selected.photoUrl != null
                                        ? Image.network(
                                            selected.photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.photo_library_outlined,
                                                ),
                                          )
                                        : image.value != null ||
                                              preview.value != null
                                        ? Image.memory(
                                            image.value ?? preview.value!,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          )
                                        : const Icon(
                                            Icons.photo_library_outlined,
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

class _PhotoProgressDots extends StatelessWidget {
  const _PhotoProgressDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Photo ${index + 1} of $count',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: dot == index ? 12 : 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: dot == index ? 1 : .55),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
