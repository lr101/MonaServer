import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One package cache for grids, full photographs and mutable avatars.
class RemoteImage extends ConsumerWidget {
  const RemoteImage({
    super.key,
    required this.image,
    this.policy = RemoteImagePolicy.thumbnail,
    this.blurhash,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.placeholder,
    this.errorWidget,
  });
  final RemoteImageReference image;
  final RemoteImagePolicy policy;
  final String? blurhash;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namespace = ref.watch(imageSessionNamespaceProvider);
    return _RemoteImageContent(
      key: ValueKey((namespace, image.kind, image.id, image.photoId, policy)),
      widget: this,
    );
  }
}

class _RemoteImageContent extends ConsumerStatefulWidget {
  const _RemoteImageContent({super.key, required this.widget});
  final RemoteImage widget;
  @override
  ConsumerState<_RemoteImageContent> createState() =>
      _RemoteImageContentState();
}

class _RemoteImageContentState extends ConsumerState<_RemoteImageContent> {
  bool _fullReady = false;
  bool _previewReleased = false;
  bool _previewReady = false;
  bool _previewFailed = false;
  bool _fullFailed = false;
  int _previewGeneration = 0;
  int _fullGeneration = 0;
  RemoteImage get image => widget.widget;

  @override
  void didUpdateWidget(covariant _RemoteImageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widget.image != image.image) {
      _previewFailed = _fullFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = image.image;
    ref.listen(
      remoteImageMetadataProvider((
        kind: reference.kind,
        id: reference.id,
        photoId: reference.photoId,
      )),
      (_, next) {
        if (!next.hasValue) return;
        // Sync may replace an ID-only avatar's URL after a successful load.
        // Invalidate metadata, keeping the decoded package subtree in place.
        for (var attempt = 0; attempt <= 3; attempt++) {
          if (reference.kind == RemoteImageKind.pin) {
            ref.invalidate(
              pinImageSourceProvider((
                pinId: reference.id,
                photoId: reference.photoId,
                thumbnailUrl: reference.thumbnailUrl,
                imageUrl: reference.imageUrl,
                attempt: attempt,
              )),
            );
          }
          ref.invalidate(
            remoteImageSourceProvider((image: reference, attempt: attempt)),
          );
        }
        setState(() {
          // Cancel a pending fallback as well as a terminal failure. Metadata
          // can arrive between an error frame and its post-frame retry.
          _previewGeneration++;
          _fullGeneration++;
          _previewFailed = _fullFailed = false;
        });
      },
    );
    final placeholder =
        image.placeholder ??
        (image.policy == RemoteImagePolicy.previewThenFull &&
                image.blurhash == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : PinImagePlaceholder(blurhash: image.blurhash));
    final error =
        image.errorWidget ??
        Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            const Center(child: Icon(Icons.image_not_supported_outlined)),
          ],
        );
    if (image.policy == RemoteImagePolicy.thumbnail) {
      return _RemoteImageStage(
        retryGeneration: _previewGeneration,
        image: image,
        initialAttempt: 0,
        step: 1,
        placeholder: placeholder,
        errorWidget: error,
        onFailed: () => setState(() => _previewFailed = true),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        if (!_previewReleased)
          _RemoteImageStage(
            key: const ValueKey('preview'),
            retryGeneration: _previewGeneration,
            image: image,
            initialAttempt: 0,
            step: 2,
            placeholder: const SizedBox.expand(),
            errorWidget: const SizedBox.expand(),
            onReady: () {
              if (!_previewReady || _previewFailed) {
                setState(() {
                  _previewReady = true;
                  _previewFailed = false;
                });
              }
            },
            onFailed: () => setState(() => _previewFailed = true),
          ),
        // Keep the decoded preview underneath until the full image is opaque.
        // Own this fade here so the package cannot fade from an empty layer.
        AnimatedOpacity(
          opacity: _fullReady ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (!_fullReady || _previewReleased) return;
            // A zero-duration transition can finish during the widget build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _fullReady && !_previewReleased) {
                setState(() => _previewReleased = true);
              }
            });
          },
          child: _RemoteImageStage(
            key: const ValueKey('full'),
            retryGeneration: _fullGeneration,
            image: image,
            initialAttempt: 1,
            step: 2,
            fadeInDuration: _fullReady
                ? const Duration(milliseconds: 320)
                : Duration.zero,
            placeholder: const SizedBox.expand(),
            errorWidget: const SizedBox.expand(),
            onReady: () {
              if (!_fullReady || _fullFailed) {
                setState(() {
                  _fullReady = true;
                  _fullFailed = false;
                });
              }
            },
            onFailed: () => setState(() => _fullFailed = true),
          ),
        ),
        if (_previewFailed && _fullFailed && !_previewReady && !_fullReady)
          error,
      ],
    );
  }
}

class _RemoteImageStage extends ConsumerStatefulWidget {
  const _RemoteImageStage({
    super.key,
    required this.image,
    required this.initialAttempt,
    required this.step,
    required this.placeholder,
    required this.errorWidget,
    this.onReady,
    this.onFailed,
    this.retryGeneration = 0,
    this.fadeInDuration = const Duration(milliseconds: 320),
  });
  final RemoteImage image;
  final int initialAttempt;
  final int step;
  final Widget placeholder;
  final Widget errorWidget;
  final VoidCallback? onReady;
  final VoidCallback? onFailed;
  final Duration fadeInDuration;
  final int retryGeneration;
  @override
  ConsumerState<_RemoteImageStage> createState() => _RemoteImageStageState();
}

class _RemoteImageStageState extends ConsumerState<_RemoteImageStage> {
  late int _attempt = widget.initialAttempt;
  bool _scheduled = false;
  bool _reportedReady = false;
  bool _reportedFailed = false;
  int _generation = 0;
  int _loadGeneration = 0;
  ImageProvider<Object>? _retainedProvider;
  ImageProvider<Object>? _transitionBackdrop;
  String? _activeCacheKey;
  PinImageSource? _displayedSource;

  @override
  void didUpdateWidget(covariant _RemoteImageStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.image != widget.image.image ||
        oldWidget.retryGeneration != widget.retryGeneration) {
      if (_scheduled || _reportedFailed || _attempt != widget.initialAttempt) {
        _loadGeneration++;
        _activeCacheKey = null;
      }
      _attempt = widget.initialAttempt;
      _scheduled = _reportedReady = _reportedFailed = false;
      _generation++;
    }
  }

  void _afterFrame(VoidCallback action) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) action();
    });
  }

  Widget _failed() {
    if (_attempt + widget.step <= 3) {
      if (!_scheduled) {
        _scheduled = true;
        _afterFrame(
          () => setState(() {
            _attempt += widget.step;
            _scheduled = false;
          }),
        );
      }
      return _retainedImage() ?? widget.placeholder;
    }
    if (!_reportedFailed) {
      _reportedFailed = true;
      _afterFrame(() => widget.onFailed?.call());
    }
    return _retainedImage() ?? widget.errorWidget;
  }

  Widget? _retainedImage() =>
      _retainedProvider == null ? null : _providerImage(_retainedProvider!);

  Widget _providerImage(ImageProvider<Object> provider) => Image(
    image: provider,
    fit: widget.image.fit,
    alignment: widget.image.alignment,
    gaplessPlayback: true,
  );

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final state = ref.watch(
      remoteImageSourceProvider((image: image.image, attempt: _attempt)),
    );
    // Keep the package subtree mounted while metadata resolves. Replacing it
    // with a plain Image here restarts its fade when the same URL returns.
    return LayoutBuilder(
      builder: (context, constraints) => state.when(
        loading: () => _displayedSource == null
            ? widget.placeholder
            : _networkImage(context, constraints, _displayedSource!),
        error: (_, _) => _failed(),
        data: (source) {
          if (source == null) return _failed();
          return _networkImage(context, constraints, source);
        },
      ),
    );
  }

  Widget _networkImage(
    BuildContext context,
    BoxConstraints constraints,
    PinImageSource source,
  ) {
    final image = widget.image;
    if (_activeCacheKey != source.cacheKey) {
      _transitionBackdrop = _retainedProvider;
      _activeCacheKey = source.cacheKey;
    }
    // Capture the preceding frame, never the newly decoded frame. Using the
    // latter as the placeholder paints it above its own fade and makes it pop.
    final backdrop = _transitionBackdrop == null
        ? widget.placeholder
        : _providerImage(_transitionBackdrop!);
    final width = constraints.maxWidth;
    final maximum = image.policy == RemoteImagePolicy.thumbnail ? 720 : 2160;
    final cacheWidth = width.isFinite
        ? (width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
            1,
            maximum,
          )
        : maximum;
    return CachedNetworkImage(
      key: ValueKey(_loadGeneration),
      imageUrl: source.url,
      cacheKey: source.cacheKey,
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      fit: image.fit,
      alignment: image.alignment,
      memCacheWidth: cacheWidth,
      fadeInDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.fadeInDuration,
      fadeOutDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.fadeInDuration,
      fadeOutCurve: Curves.easeOutCubic,
      fadeInCurve: Curves.easeOutCubic,
      useOldImageOnUrlChange: _retainedProvider != null,
      placeholder: (_, _) => backdrop,
      imageBuilder: (context, provider) {
        final resized = ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
        _retainedProvider = resized;
        _displayedSource = source;
        if (!_reportedReady) {
          _reportedReady = true;
          _afterFrame(() => widget.onReady?.call());
        }
        return Image(
          image: resized,
          fit: image.fit,
          alignment: image.alignment,
          gaplessPlayback: true,
        );
      },
      errorWidget: (_, _, _) {
        ref
            .read(remoteImageSourcesProvider)
            .invalidate(image.image, _attempt, source.url);
        return _failed();
      },
    );
  }
}
