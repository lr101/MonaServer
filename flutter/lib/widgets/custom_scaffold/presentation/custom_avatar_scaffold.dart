import 'dart:typed_data';

import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomAvatarScaffold extends ConsumerStatefulWidget {
  const CustomAvatarScaffold(
      {super.key,
      required this.avatar,
      required this.title,
      this.boxes,
      this.bottom,
      this.actions,
      this.floatingActionButton,
      this.profileQuickViewBoxes,
      this.hasBackButton = true,
      required this.body,});

  final AsyncValue<Uint8List?> avatar;
  final Widget title;
  final List<SliverToBoxAdapter>? boxes;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final Widget? profileQuickViewBoxes;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool hasBackButton;

  @override
  ConsumerState<CustomAvatarScaffold> createState() =>
      _CustomAvatarScaffoldState();
}

class _CustomAvatarScaffoldState extends ConsumerState<CustomAvatarScaffold>
    with TickerProviderStateMixin {
  ScrollController controller = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double leftPadding = widget.hasBackButton ? 66.0 : 16.0;

    return Scaffold(
      body: NestedScrollView(
        controller: controller,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            actions: widget.actions,
            expandedHeight: 180,
            centerTitle: false,
            title: widget.title,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(left: leftPadding, top: 60, right: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: RoundImage(
                          imageCallback: widget.avatar,
                          size: 40, // size is half of dimension
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: widget.profileQuickViewBoxes ?? const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: widget.bottom,
          ),
          if (widget.boxes != null) ...widget.boxes!,
        ],
        body: widget.body,
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
