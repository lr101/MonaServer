import 'dart:typed_data';

import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/remote_image/remote_round_image.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double _defaultExpandedHeight = 180;
const double _avatarDimension = 88;
// An 80 px image leaves room for the 86 px XP ring without changing the image
// bounds when progression data arrives.
const double _avatarImageRadius = 40;
const double _bottomContentSpacing = 12;

class CustomAvatarScaffold extends ConsumerStatefulWidget {
  const CustomAvatarScaffold({
    super.key,
    this.avatar = const AsyncData(null),
    this.remoteAvatar,
    required this.title,
    this.boxes,
    this.avatarBuilder,
    this.bottom,
    this.actions,
    this.toolbarHeight = kToolbarHeight,
    this.profileContentHeight = _avatarDimension,
    this.avatarEditAction,
    this.avatarEditTooltip = 'Edit profile',
    this.floatingActionButton,
    this.profileQuickViewBoxes,
    this.hasBackButton = true,
    required this.body,
  });

  final AsyncValue<Uint8List?> avatar;
  final RemoteImageReference? remoteAvatar;
  final Widget title;
  final Widget Function(Widget avatar)? avatarBuilder;
  final List<SliverToBoxAdapter>? boxes;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final Widget? profileQuickViewBoxes;
  final List<Widget>? actions;
  final double toolbarHeight;
  final double profileContentHeight;
  final VoidCallback? avatarEditAction;
  final String avatarEditTooltip;
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

  Widget _buildAvatar() {
    final avatar = widget.remoteAvatar != null
        ? RemoteRoundImage(
            image: widget.remoteAvatar!,
            radius: _avatarImageRadius,
            progressive: true,
          )
        : RoundImage(imageCallback: widget.avatar, size: _avatarImageRadius);
    return widget.avatarBuilder?.call(avatar) ?? avatar;
  }

  @override
  Widget build(BuildContext context) {
    final double leftPadding = widget.hasBackButton ? 66.0 : 16.0;
    // SliverAppBar's expanded height includes its bottom widget.
    final avatarTopPadding = widget.toolbarHeight + 4;
    final bottomHeight = widget.bottom?.preferredSize.height ?? 0;
    final contentHeight =
        avatarTopPadding +
        widget.profileContentHeight.clamp(_avatarDimension, double.infinity) +
        bottomHeight +
        _bottomContentSpacing;
    final expandedHeight =
        widget.bottom == null && contentHeight < _defaultExpandedHeight
        ? _defaultExpandedHeight
        : contentHeight;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final headerBg = isWide
        ? colors.surface
        : (isLight ? colors.surfaceContainerLowest : colors.surfaceContainerLow);
    final profileRowHeight = widget.profileContentHeight.clamp(
      _avatarDimension,
      double.infinity,
    );

    final canPop = Navigator.of(context).canPop();
    final tabBar = widget.bottom == null
        ? null
        : isWide
        ? PreferredSize(
            preferredSize: widget.bottom!.preferredSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.bottom!,
            ),
          )
        : widget.bottom;

    final scrollView = NestedScrollView(
      controller: controller,
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          floating: true,
          actions: widget.actions,
          toolbarHeight: widget.toolbarHeight,
          expandedHeight: expandedHeight,
          centerTitle: canPop,
          title: widget.title,
          backgroundColor: headerBg,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: leftPadding,
                  top: avatarTopPadding,
                  right: 16,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    height: profileRowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: _avatarDimension,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Keep loose constraints so RoundImage's circular
                              // background stays the same size as its image.
                              _buildAvatar(),
                              if (widget.avatarEditAction != null)
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: headerBg,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: IconButton.filledTonal(
                                      tooltip: widget.avatarEditTooltip,
                                      onPressed: widget.avatarEditAction,
                                      iconSize: 15,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 28,
                                            height: 28,
                                          ),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            colors.surfaceContainerHigh,
                                        foregroundColor: colors.onSurface,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.edit),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: isWide ? 28 : 16),
                        Expanded(
                          child: Align(
                            alignment: isWide
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isWide ? 360 : double.infinity,
                              ),
                              child:
                                  widget.profileQuickViewBoxes ??
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottom: tabBar,
        ),
        if (widget.boxes != null) ...widget.boxes!,
      ],
      body: widget.body,
    );

    return Scaffold(
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: scrollView,
              ),
            )
          : scrollView,
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
