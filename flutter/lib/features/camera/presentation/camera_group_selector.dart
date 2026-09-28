import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:flutter/material.dart';

/// A centered, bounded group carousel with a fixed shutter target.
class CameraGroupSelector extends StatelessWidget {
  const CameraGroupSelector({
    required this.controller,
    required this.children,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.onCapture,
    super.key,
  });

  final PageController controller;
  final List<Widget> children;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onCapture;

  static const double maxCarouselWidth = 420;
  static const double itemViewportFraction = 0.24;
  static const double shutterRingSize = 100;
  static const double shutterRingStrokeWidth = 5;
  static const double shutterImageSize =
      shutterRingSize - shutterRingStrokeWidth * 2;

  @override
  Widget build(BuildContext context) {
    final height = cameraGroupSelectorHeight(MediaQuery.sizeOf(context).height);
    final activeIndex = children.isEmpty
        ? 0
        : selectedIndex.clamp(0, children.length - 1);
    const shutterSize = shutterRingSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final carouselWidth = constraints.maxWidth < maxCarouselWidth
            ? constraints.maxWidth
            : maxCarouselWidth;
        return SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: carouselWidth,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: PageView(
                      controller: controller,
                      onPageChanged: onPageChanged,
                      children: [
                        for (var index = 0; index < children.length; index++)
                          Semantics(
                            button: true,
                            label: index == activeIndex
                                ? 'Take photo'
                                : 'Select group',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onCapture(index),
                              child: children[index],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      key: const ValueKey('camera-group-shutter-ring'),
                      width: shutterSize,
                      height: shutterSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: shutterRingStrokeWidth,
                          color: Theme.of(context).colorScheme.primaryOnSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double cameraGroupSelectorHeight(double screenHeight) =>
    (screenHeight * .12).clamp(112.0, 128.0);

double cameraGroupAvatarSize(double screenHeight) =>
    (cameraGroupSelectorHeight(screenHeight) * .58).clamp(44.0, 52.0);
