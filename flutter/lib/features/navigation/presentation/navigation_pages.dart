import 'dart:async';

import 'package:buff_lisa/features/navigation/presentation/floating_navigation_dock.dart';
import 'package:flutter/material.dart';

/// Retains visited destinations while the viewport slides to the selected page.
class NavigationPages extends StatefulWidget {
  const NavigationPages({
    super.key,
    required this.selectedIndex,
    required this.children,
  });
  final int selectedIndex;
  final List<Widget> children;
  @override
  State<NavigationPages> createState() => _NavigationPagesState();
}

class _NavigationPagesState extends State<NavigationPages> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant NavigationPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _selectPage();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _controller.hasClients) {
      _controller.jumpToPage(widget.selectedIndex);
    }
  }

  void _selectPage() {
    if (!_controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectPage();
      });
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(widget.selectedIndex);
    } else {
      unawaited(
        _controller.animateToPage(
          widget.selectedIndex,
          duration: navigationTransitionDuration,
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    controller: _controller,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (var index = 0; index < widget.children.length; index++)
        _RetainedNavigationPage(
          key: ValueKey(index),
          active: index == widget.selectedIndex,
          child: widget.children[index],
        ),
    ],
  );
}

class _RetainedNavigationPage extends StatefulWidget {
  const _RetainedNavigationPage({
    super.key,
    required this.active,
    required this.child,
  });
  final bool active;
  final Widget child;
  @override
  State<_RetainedNavigationPage> createState() =>
      _RetainedNavigationPageState();
}

class _RetainedNavigationPageState extends State<_RetainedNavigationPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.active, child: widget.child);
  }
}
