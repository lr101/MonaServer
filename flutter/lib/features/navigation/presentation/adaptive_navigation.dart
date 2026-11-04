import 'package:buff_lisa/features/navigation/presentation/floating_navigation_dock.dart';
import 'package:flutter/material.dart';

/// Keeps the page subtree in place while switching navigation for the window.
class AdaptiveNavigation extends StatefulWidget {
  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.backgroundColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final Color? backgroundColor;

  @override
  State<AdaptiveNavigation> createState() => _AdaptiveNavigationState();
}

class _AdaptiveNavigationState extends State<AdaptiveNavigation> {
  bool _railCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final canExpand = MediaQuery.sizeOf(context).width >= 900;
    final expandedRail = canExpand && !_railCollapsed;
    final media = MediaQuery.of(context);
    final showDock = !wide && media.viewInsets.bottom == 0;
    final contentBottomInset = showDock
        ? media.padding.bottom + navigationDockHeight + navigationDockMargin * 2
        : media.padding.bottom;
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: widget.selectedIndex,
                    onDestinationSelected: widget.onDestinationSelected,
                    extended: expandedRail,
                    minExtendedWidth: 180,
                    labelType: expandedRail
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLow,
                    leading: canExpand
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: expandedRail
                                      ? 'Collapse navigation'
                                      : 'Expand navigation',
                                  icon: Icon(
                                    expandedRail ? Icons.menu_open : Icons.menu,
                                  ),
                                  onPressed: () => setState(
                                    () => _railCollapsed = !_railCollapsed,
                                  ),
                                ),
                                if (expandedRail)
                                  Text(
                                    'Stick-It',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          )
                        : null,
                    scrollable: true,
                    destinations: [
                      for (final item in navigationDestinations)
                        NavigationRailDestination(
                          icon: Icon(item.$1),
                          selectedIcon: Icon(item.$2),
                          label: Text(item.$3),
                        ),
                    ],
                  ),
                ),
              Expanded(
                key: const ValueKey('navigation-content'),
                child: Builder(
                  builder: (context) {
                    final contentMedia = MediaQuery.of(context);
                    return MediaQuery(
                      data: contentMedia.copyWith(
                        padding: contentMedia.padding.copyWith(
                          bottom: contentBottomInset,
                        ),
                      ),
                      child: widget.child,
                    );
                  },
                ),
              ),
            ],
          ),
          if (showDock)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + navigationDockMargin,
              child: FloatingNavigationDock(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
              ),
            ),
        ],
      ),
    );
  }
}
