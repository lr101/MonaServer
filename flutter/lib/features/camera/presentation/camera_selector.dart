import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraSelectorButton extends StatefulWidget {
  const CameraSelectorButton({
    required this.cameras,
    required this.selectedIndex,
    required this.onSelected,
    this.maxMenuHeight = 240,
    this.menuBottomSpacing = 0,
    super.key,
  });

  final List<CameraDescription> cameras;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double maxMenuHeight;
  final double menuBottomSpacing;

  @override
  State<CameraSelectorButton> createState() => _CameraSelectorButtonState();
}

class _CameraSelectorButtonState extends State<CameraSelectorButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  bool _open = false;

  void _setOpen(bool open) {
    setState(() => _open = open);
    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = _cameraLabels(widget.cameras);
    final selectedIndex = widget.cameras.isEmpty
        ? 0
        : widget.selectedIndex.clamp(0, widget.cameras.length - 1);
    return TapRegion(
      onTapOutside: (_) {
        if (_open) _setOpen(false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Offstage(
              offstage: _controller.isDismissed,
              child: ClipRect(
                child: SizeTransition(
                  sizeFactor: _animation,
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_animation),
                    child: IgnorePointer(ignoring: !_open, child: child),
                  ),
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 8 + widget.menuBottomSpacing),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 240,
                    maxHeight: widget.maxMenuHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.cameras.length, (index) {
                        return ListTile(
                          leading: Icon(
                            _cameraIcon(widget.cameras[index].lensDirection),
                          ),
                          title: Text(labels[index]),
                          selected: index == selectedIndex,
                          trailing: index == selectedIndex
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () {
                            _setOpen(false);
                            widget.onSelected(index);
                          },
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.grey.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Select camera',
              onPressed: widget.cameras.isEmpty ? null : () => _setOpen(!_open),
              icon: const Icon(Icons.flip_camera_android),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _cameraLabels(List<CameraDescription> cameras) {
  final counts = <CameraLensDirection, int>{};
  final seen = <CameraLensDirection, int>{};
  for (final camera in cameras) {
    counts.update(
      camera.lensDirection,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  return cameras.map((camera) {
    final direction = camera.lensDirection;
    final occurrence = (seen[direction] ?? 0) + 1;
    seen[direction] = occurrence;
    final label = _cameraLabel(direction);
    return counts[direction] == 1 ? label : '$label $occurrence';
  }).toList();
}

String _cameraLabel(CameraLensDirection direction) {
  return switch (direction) {
    CameraLensDirection.back => 'Back camera',
    CameraLensDirection.front => 'Front camera',
    CameraLensDirection.external => 'External camera',
  };
}

IconData _cameraIcon(CameraLensDirection direction) {
  return switch (direction) {
    CameraLensDirection.back => Icons.camera_rear,
    CameraLensDirection.front => Icons.camera_front,
    CameraLensDirection.external => Icons.videocam,
  };
}
