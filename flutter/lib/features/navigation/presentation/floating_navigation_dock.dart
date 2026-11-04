import 'dart:ui' show SemanticsRole;

import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:flutter/material.dart';

const navigationTransitionDuration = Duration(milliseconds: 320);
const navigationDockHeight = 64.0;
const navigationDockMargin = 12.0;

/// Shared horizontal bounds for the dock and its attached map tray.
double navigationDockWidth(double availableWidth) {
  final margin = ((availableWidth - 252) / 2).clamp(0.0, 16.0);
  return (availableWidth - margin * 2).clamp(0.0, 360.0);
}

const navigationDestinations = <(IconData, IconData, String)>[
  (Icons.group_outlined, Icons.group, 'Groups'),
  (Icons.camera_alt_outlined, Icons.camera_alt, 'Camera'),
  (Icons.map_outlined, Icons.map, 'Map'),
  (Icons.dynamic_feed_outlined, Icons.dynamic_feed, 'Feed'),
  (Icons.person_outline, Icons.person, 'Profile'),
];

/// Only the capsule paints or intercepts input; its surrounding overlay is clear.
class FloatingNavigationDock extends StatelessWidget {
  const FloatingNavigationDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : navigationTransitionDuration;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = navigationDockWidth(constraints.maxWidth);
        final padding = width >= 252 ? 6.0 : 0.0;
        final innerWidth = width - padding * 2;
        final expansion = (innerWidth - navigationDestinations.length * 48)
            .clamp(0.0, 16.0);
        final itemWidth =
            (innerWidth - expansion) / navigationDestinations.length;
        return Center(
          child: Material(
            key: const ValueKey('floating-navigation-dock'),
            color: colors.surfaceContainer,
            surfaceTintColor: Colors.transparent,
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              height: navigationDockHeight,
              child: Semantics(
                role: SemanticsRole.tabBar,
                label: 'Main navigation',
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      left: padding + selectedIndex * itemWidth,
                      top: 6,
                      bottom: 6,
                      width: itemWidth + expansion,
                      child: DecoratedBox(
                        key: const ValueKey('floating-dock-indicator'),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < navigationDestinations.length;
                            index++
                          )
                            AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              width:
                                  itemWidth +
                                  (index == selectedIndex ? expansion : 0),
                              height: navigationDockHeight,
                              child: Semantics(
                                role: SemanticsRole.tab,
                                selected: index == selectedIndex,
                                label: navigationDestinations[index].$3,
                                onTap: () => onDestinationSelected(index),
                                excludeSemantics: true,
                                child: Tooltip(
                                  message: navigationDestinations[index].$3,
                                  excludeFromSemantics: true,
                                  child: InkWell(
                                    excludeFromSemantics: true,
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: () => onDestinationSelected(index),
                                    child: Center(
                                      child: TweenAnimationBuilder<double>(
                                        duration: duration,
                                        curve: Curves.easeOutCubic,
                                        tween: Tween(
                                          end: index == selectedIndex ? 28 : 24,
                                        ),
                                        builder: (context, size, _) => Icon(
                                          index == selectedIndex
                                              ? navigationDestinations[index].$2
                                              : navigationDestinations[index]
                                                    .$1,
                                          size: size,
                                          color: index == selectedIndex
                                              ? colors.primaryOnSurface
                                              : colors.onSurfaceVariant,
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
