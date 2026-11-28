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
              if (wide) ...[
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: SafeArea(
                    child: Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        final colors = theme.colorScheme;
                        final isLight = theme.brightness == Brightness.light;
                        final activeColor = isLight
                            ? const Color(0xFF9A5B00)
                            : colors.primary;
                        final activePillBg = colors.primary.withValues(
                          alpha: isLight ? 0.28 : 0.24,
                        );
                        return NavigationRail(
                          selectedIndex: widget.selectedIndex,
                          onDestinationSelected: widget.onDestinationSelected,
                          extended: expandedRail,
                          minExtendedWidth: 216,
                          useIndicator: true,
                          indicatorColor: activePillBg,
                          indicatorShape: const StadiumBorder(),
                          selectedIconTheme: IconThemeData(
                            color: activeColor,
                            size: 22,
                          ),
                          unselectedIconTheme: IconThemeData(
                            color: colors.onSurfaceVariant,
                            size: 22,
                          ),
                          selectedLabelTextStyle: TextStyle(
                            fontFamily: 'Signika',
                            fontSize: expandedRail ? 15 : 12,
                            fontWeight: FontWeight.w700,
                            color: activeColor,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            fontFamily: 'Signika',
                            fontSize: expandedRail ? 15 : 12,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                          labelType: expandedRail
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.all,
                          backgroundColor: colors.surfaceContainerLowest,
                          leading: canExpand
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    16,
                                  ),
                                  child: SizedBox(
                                    width: expandedRail ? 184 : null,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: expandedRail
                                              ? 'Collapse navigation'
                                              : 'Expand navigation',
                                          icon: Icon(
                                            expandedRail
                                                ? Icons.menu_open
                                                : Icons.menu,
                                          ),
                                          onPressed: () => setState(
                                            () => _railCollapsed =
                                                !_railCollapsed,
                                          ),
                                        ),
                                        if (expandedRail) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Stick-It',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 20,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                          scrollable: true,
                          destinations: [
                            for (final destination in navigationDestinations)
                              NavigationRailDestination(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                icon: Icon(destination.$1),
                                selectedIcon: Icon(destination.$2),
                                label: expandedRail
                                    ? SizedBox(
                                        width: 112,
                                        child: Text(
                                          destination.$3,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : Text(destination.$3),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ],
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
