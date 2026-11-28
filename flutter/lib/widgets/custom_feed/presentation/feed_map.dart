import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_map_setup/presentation/custom_tile_layer.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';

/// Map rendering boundary, overridable when platform tile storage is unavailable.
final feedMapBuilderProvider = Provider<Widget Function(PinEntity)>(
  (ref) =>
      (pin) => FeedMap(item: pin),
);

class FeedMap extends ConsumerStatefulWidget {
  const FeedMap({super.key, required this.item});
  final PinEntity item;

  @override
  ConsumerState<FeedMap> createState() => FeedMapState();
}

class FeedMapState extends ConsumerState<FeedMap> {
  MapController? _mapController;
  late LatLng center;
  late double _zoom;

  @override
  void initState() {
    super.initState();
    center = LatLng(widget.item.latitude, widget.item.longitude);
    _zoom = 5;
  }

  @override
  void didUpdateWidget(covariant FeedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.latitude != widget.item.latitude ||
        oldWidget.item.longitude != widget.item.longitude) {
      center = LatLng(widget.item.latitude, widget.item.longitude);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  MapController _ensureMapController() => _mapController ??= MapController();

  @override
  Widget build(BuildContext context) {
    final isExpanded = !ref.watch(feedMapStateProvider(widget.item.entryId));
    final switchFun = ref
        .read(feedMapStateProvider(widget.item.entryId).notifier)
        .update;
    if (!isExpanded) {
      return GestureDetector(
        onTap: switchFun,
        child: const _CollapsedMapPreview(),
      );
    }
    final mapController = _ensureMapController();
    return Stack(
      children: [
        GestureDetector(
          onDoubleTap: like,
          child: AbsorbPointer(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A2029)
                    : const Color(0xFFEAECE8),
                minZoom: 2,
                maxZoom: 18,
                initialZoom: _zoom,
                initialCenter: center,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom,
                ),
              ),
              children: [
                CustomTileLayer(),
                MarkerLayer(markers: [CustomMarkerWidget(pinDto: widget.item)]),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _MapControlButton(
                  onTap: () => zoomIn(center),
                  theme: Theme.of(context),
                  icon: Icons.zoom_in,
                ),
                const SizedBox(height: 5),
                _MapControlButton(
                  onTap: () => zoomOut(center),
                  theme: Theme.of(context),
                  icon: Icons.zoom_out_rounded,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void zoomIn(LatLng center) {
    final controller = _mapController;
    if (controller == null) return;
    controller.move(center, controller.camera.zoom + 1);
  }

  void zoomOut(LatLng center) {
    final controller = _mapController;
    if (controller == null) return;
    controller.move(center, controller.camera.zoom - 1);
  }

  void like() {
    final userId = ref.read(globalDataServiceProvider).userId;
    if (userId == null) return;
    ref
        .read(likeServiceProvider(widget.item.entryId).notifier)
        .addLike(
          widget.item.creator,
          CreateLikeDto(userId: userId, like: true),
        );
  }
}

class _CollapsedMapPreview extends StatelessWidget {
  const _CollapsedMapPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final bgStart = isLight ? const Color(0xFFE6F0EC) : const Color(0xFF1B242C);
    final bgEnd = isLight ? const Color(0xFFD6E4EC) : const Color(0xFF24303B);
    final roadColor = isLight
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.12);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
      ),
      child: CustomPaint(
        painter: _MiniMapLinesPainter(roadColor: roadColor),
        child: Align(
          alignment: const Alignment(0, -0.26),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: isLight ? const Color(0xFFD97706) : colors.primary,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapLinesPainter extends CustomPainter {
  const _MiniMapLinesPainter({required this.roadColor});

  final Color roadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final major = Paint()
      ..color = roadColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = roadColor.withValues(alpha: roadColor.a * 0.65)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(-4, size.height * 0.28),
      Offset(size.width + 4, size.height * 0.48),
      major,
    );
    canvas.drawLine(
      Offset(size.width * 0.26, -4),
      Offset(size.width * 0.56, size.height + 4),
      major,
    );
    canvas.drawLine(
      Offset(-4, size.height * 0.64),
      Offset(size.width + 4, size.height * 0.52),
      minor,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, -4),
      Offset(size.width * 0.60, size.height + 4),
      minor,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapLinesPainter oldDelegate) =>
      oldDelegate.roadColor != roadColor;
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 45, // Smaller than FAB (56)
          height: 45,
          decoration: BoxDecoration(
            // Semi-transparent surface color (frosted glass effect)
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: theme.colorScheme.onSurface, size: 20),
        ),
      ),
    );
  }
}
