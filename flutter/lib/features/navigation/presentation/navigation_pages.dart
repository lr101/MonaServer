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
  static const int _retainedPageLimit = 2;
  late final PageController _controller;
  final List<int> _retainedPages = [];

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.selectedIndex);
    _rememberPage(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant NavigationPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _rememberPage(widget.selectedIndex);
      _selectPage();
    }
  }

  void _rememberPage(int index) {
    _retainedPages
      ..remove(index)
      ..add(index);
    if (_retainedPages.length > _retainedPageLimit) {
      _retainedPages.removeAt(0);
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
          retained: _retainedPages.contains(index),
          child: widget.children[index],
        ),
    ],
  );
}

class _RetainedNavigationPage extends StatefulWidget {
  const _RetainedNavigationPage({
    super.key,
    required this.active,
    required this.retained,
    required this.child,
  });
  final bool active;
  final bool retained;
  final Widget child;
  @override
  State<_RetainedNavigationPage> createState() =>
      _RetainedNavigationPageState();
}

class _RetainedNavigationPageState extends State<_RetainedNavigationPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.retained;

  @override
  void didUpdateWidget(covariant _RetainedNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retained != widget.retained) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TickerMode(enabled: widget.active, child: widget.child);
  }
}
