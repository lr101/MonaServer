import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class CustomScaffold<T> extends ConsumerWidget {
  final double? headerHeight;
  final Widget title;
  final Widget? flexibleSpace;
  final List<Widget> boxes;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final ItemWidgetBuilder<T> listBuilder;
  final PagingController<int, T> pagingController;
  final double? maxWidth;
  final Widget? footer;
  final Widget? emptyState;
  final int Function(double width)? gridColumnsBuilder;
  final double gridMainAxisExtent;

  const CustomScaffold({
    super.key,
    required this.title,
    required this.listBuilder,
    required this.pagingController,
    this.boxes = const [],
    this.flexibleSpace,
    this.actions,
    this.bottom,
    this.headerHeight,
    this.maxWidth,
    this.footer,
    this.emptyState,
    this.gridColumnsBuilder,
    this.gridMainAxisExtent = 96,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = gridColumnsBuilder?.call(screenWidth) ?? 1;
    final bottomPadding = footer != null
        ? 8.0
        : MediaQuery.paddingOf(context).bottom + 16;

    final scrollView = CustomScrollView(
      slivers: [
        SliverAppBar(
          snap: true,
          floating: true,
          centerTitle: false,
          actions: actions,
          title: title,
          expandedHeight: headerHeight,
          flexibleSpace: flexibleSpace != null
              ? SafeArea(child: flexibleSpace!)
              : null,
          bottom: bottom,
        ),
        ...boxes.map((e) => SliverToBoxAdapter(child: e)),
        SliverPadding(
          padding: columns > 1
              ? EdgeInsets.fromLTRB(16, 8, 16, bottomPadding)
              : EdgeInsets.only(bottom: bottomPadding),
          sliver: PagingListener<int, T>(
            controller: pagingController,
            builder: (context, state, fetchNextPage) {
              final delegate = PagedChildBuilderDelegate<T>(
                itemBuilder: listBuilder,
                noItemsFoundIndicatorBuilder: emptyState != null
                    ? (_) => emptyState!
                    : null,
              );
              if (columns > 1) {
                return PagedSliverGrid<int, T>(
                  state: state,
                  fetchNextPage: fetchNextPage,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: gridMainAxisExtent,
                  ),
                  builderDelegate: delegate,
                );
              }
              return PagedSliverList<int, T>(
                state: state,
                fetchNextPage: fetchNextPage,
                builderDelegate: delegate,
              );
            },
          ),
        ),
        if (footer != null)
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            sliver: SliverToBoxAdapter(child: footer),
          ),
      ],
    );

    return CustomCloseKeyboardScaffold(
      body: maxWidth == null
          ? scrollView
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth!),
                child: scrollView,
              ),
            ),
    );
  }
}
