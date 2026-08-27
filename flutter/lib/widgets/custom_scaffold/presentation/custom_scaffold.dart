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

  const CustomScaffold({super.key,
    required this.title,
    required this.listBuilder,
    required this.pagingController,
    this.boxes = const [],
    this.flexibleSpace,
    this.actions,
    this.bottom,
    this.headerHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomCloseKeyboardScaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            snap: true,
            floating: true,
            actions: actions,
            title: title,
            expandedHeight: headerHeight,
            flexibleSpace: flexibleSpace != null ? SafeArea(child: flexibleSpace!) : null,
            bottom: bottom,
          ),
          ...boxes.map((e) => SliverToBoxAdapter(child: e)),
          PagedSliverList<int, T>(
            pagingController: pagingController,
            builderDelegate: PagedChildBuilderDelegate<T>(
              itemBuilder: listBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
