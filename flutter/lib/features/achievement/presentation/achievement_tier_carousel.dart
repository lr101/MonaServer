import 'package:flutter/material.dart';

int activeAchievementTierIndex<T>(
  List<T> tiers,
  bool Function(T tier) isClaimed,
) {
  if (tiers.isEmpty) return 0;
  final activeIndex = tiers.indexWhere((tier) => !isClaimed(tier));
  return activeIndex < 0 ? tiers.length - 1 : activeIndex;
}

class AchievementTierCarousel extends StatefulWidget {
  const AchievementTierCarousel({
    super.key,
    required this.title,
    required this.tierCount,
    required this.initialPage,
    required this.itemBuilder,
    this.pageHeight = 96,
  });

  final String title;
  final int tierCount;
  final int initialPage;
  final IndexedWidgetBuilder itemBuilder;
  final double pageHeight;

  @override
  State<AchievementTierCarousel> createState() =>
      _AchievementTierCarouselState();
}

class _AchievementTierCarouselState extends State<AchievementTierCarousel> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _clampedInitialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(AchievementTierCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPage = _clampedInitialPage;
    if (oldWidget.initialPage != widget.initialPage ||
        _currentPage >= widget.tierCount) {
      _currentPage = nextPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  int get _clampedInitialPage => widget.tierCount <= 0
      ? 0
      : widget.initialPage.clamp(0, widget.tierCount - 1);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${widget.title} achievement tiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: widget.pageHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.tierCount,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
