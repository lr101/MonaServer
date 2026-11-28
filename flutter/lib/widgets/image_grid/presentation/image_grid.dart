import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

class ImageGrid extends ConsumerStatefulWidget {
  const ImageGrid({
    super.key,
    required this.pinProvider,
    this.onRefresh,
    this.header,
  });

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;
  final Future<void> Function()? onRefresh;
  final Widget? header;

  @override
  ConsumerState<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<ImageGrid> {
  static const int _columns = 3;
  static const double _spacing = 6;
  List<PinEntity> _images = const [];
  Map<String, int> _indexByEntryId = const {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.pinProvider);
    if (state.hasValue) {
      final nextImages = state.value ?? const <PinEntity>[];
      if (!identical(_images, nextImages)) {
        _images = nextImages;
        _indexByEntryId = {
          for (var i = 0; i < _images.length; i++) _images[i].entryId: i,
        };
      }
    }

    if (_images.isEmpty) {
      final emptyBody = Center(
        child: state.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load images'),
                  if (widget.onRefresh != null)
                    TextButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Retry'),
                    ),
                ],
              )
            : state.isLoading
            ? const CircularProgressIndicator()
            : const Text('No images found'),
      );
      if (widget.header == null) return emptyBody;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.header!,
          Expanded(child: emptyBody),
        ],
      );
    }

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final columns = constraints.maxWidth >= 680 ? 4 : _columns;
        const horizontalInset = 16.0;
        final gridPadding = EdgeInsets.fromLTRB(
          padding.left + horizontalInset,
          10,
          padding.right + horizontalInset,
          padding.bottom + 20,
        );
        final contentWidth =
            (constraints.maxWidth - gridPadding.horizontal).clamp(
              1.0,
              double.infinity,
            );
        final tileWidth = (contentWidth - _spacing * (columns - 1)) / columns;
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
        );
        Widget itemBuilder(BuildContext context, int index) {
          final item = _images[index];
          return ClipRRect(
            key: ValueKey(item.entryId),
            borderRadius: BorderRadius.circular(10),
            child: SquareImage(
              pinId: item.pinId,
              imageBlurhash: item.imageBlurhash,
              photoUrl: item.photoUrl,
              photoThumbnailUrl: item.photoThumbnailUrl,
              photoId: item.photoId,
              index: index,
              groupId: item.groupId,
              onTap: (index) {
                context.pushNamed(
                  'viewImage',
                  pathParameters: {'id': item.pinId},
                  queryParameters: item.photoId == null
                      ? {}
                      : {'photo': item.photoId},
                );
              },
            ),
          );
        }

        if (widget.header != null) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            primary: true,
            scrollCacheExtent: ScrollCacheExtent.pixels(tileWidth * 2),
            slivers: [
              SliverToBoxAdapter(child: widget.header),
              SliverPadding(
                padding: gridPadding,
                sliver: SliverGrid(
                  gridDelegate: delegate,
                  delegate: SliverChildBuilderDelegate(
                    itemBuilder,
                    childCount: _images.length,
                    findChildIndexCallback: (key) {
                      if (key is! ValueKey<String>) return null;
                      return _indexByEntryId[key.value];
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          primary: true,
          padding: gridPadding,
          // Keep nearby rows mounted; each tile loads and fades in its image as
          // it approaches the view. RemoteImage shares downloads and cache.
          scrollCacheExtent: ScrollCacheExtent.pixels(tileWidth * 2),
          itemCount: _images.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            return _indexByEntryId[key.value];
          },
          gridDelegate: delegate,
          itemBuilder: itemBuilder,
        );
      },
    );
    final refreshableGrid = widget.onRefresh == null
        ? grid
        : RefreshIndicator(onRefresh: widget.onRefresh!, child: grid);
    if (!state.hasError) return refreshableGrid;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            title: const Text('Unable to refresh images'),
            trailing: widget.onRefresh == null
                ? null
                : TextButton(
                    onPressed: widget.onRefresh,
                    child: const Text('Retry'),
                  ),
          ),
        ),
        Expanded(child: refreshableGrid),
      ],
    );
  }
}
