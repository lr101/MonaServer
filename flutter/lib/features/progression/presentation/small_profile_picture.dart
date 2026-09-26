import 'dart:typed_data';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/progression/data/profile_picture_progression_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_cached_image.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A compact, consistently sized user or group avatar with its progression.
///
/// The progression providers use the shared batch-read coalescer, so lists of
/// these widgets load their levels together instead of issuing one request per
/// visible avatar.
class SmallProfilePicture extends ConsumerWidget {
  const SmallProfilePicture.user({
    super.key,
    required this.userId,
    this.radius = 25,
    this.imageCallback,
    this.cachedImageOnly = false,
    this.loadImage = true,
    this.showProgressRing = false,
    this.child,
    this.placeholderAvatar,
  }) : groupId = null,
       imageUrl = null;

  const SmallProfilePicture.group({
    super.key,
    required this.groupId,
    this.radius = 25,
    this.imageCallback,
    this.cachedImageOnly = false,
    this.loadImage = true,
    this.child,
    this.placeholderAvatar,
    this.imageUrl,
  }) : userId = null,
       showProgressRing = false;

  final String? userId;
  final String? groupId;
  final double radius;
  final AsyncValue<Uint8List?>? imageCallback;
  final bool cachedImageOnly;
  final bool loadImage;
  final bool showProgressRing;
  final Widget? child;
  final Widget? placeholderAvatar;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = imageCallback ?? _watchImage(ref);
    final avatar = _buildAvatar(image);
    if (userId == null && groupId == null) return avatar;

    if (userId case final id?) {
      if (showProgressRing && ref.watch(userIdProvider) == id) {
        return ref
            .watch(userXpProvider(id))
            .when(
              data: (xp) => xp == null
                  ? avatar
                  : UserXpAvatarIndicator(
                      progress: XpLevelProgress.fromDto(xp),
                      avatar: avatar,
                      radius: radius,
                    ),
              error: (_, _) => avatar,
              loading: () => avatar,
            );
      }
      return ref
          .watch(userAvatarProgressionProvider(id))
          .when(
            data: (progression) => progression == null
                ? avatar
                : AvatarLevelBadge(
                    level: progression.level,
                    avatar: avatar,
                    radius: radius,
                  ),
            error: (_, _) => avatar,
            loading: () => avatar,
          );
    }

    final id = groupId!;
    return ref
        .watch(groupAvatarProgressionProvider(id))
        .when(
          skipLoadingOnRefresh: false,
          data: (progression) => progression == null
              ? avatar
              : AvatarLevelBadge(
                  level: progression.level,
                  avatar: avatar,
                  radius: radius,
                ),
          error: (_, _) => avatar,
          loading: () => avatar,
        );
  }

  AsyncValue<Uint8List?> _watchImage(WidgetRef ref) {
    if (!loadImage) return const AsyncData(null);
    if (userId case final id?) {
      return ref.watch(getUserProfileSmallProvider(id));
    }
    final id = groupId!;
    if (imageUrl case final url? when url.isNotEmpty) {
      return ref.watch(
        groupProfilePictureSmallByUrlProvider((groupId: id, url: url)),
      );
    }
    return ref.watch(groupProfilePictureSmallByIdProvider(id));
  }

  Widget _buildAvatar(AsyncValue<Uint8List?> image) {
    if (!loadImage && placeholderAvatar != null) return placeholderAvatar!;
    // Progression adds a 3 px margin around the image. Keep the ordinary
    // avatar at that outside size so the widget's footprint does not jump
    // while a batch response is loading.
    final imageRadius = radius + 3;
    if (cachedImageOnly) {
      return RoundCachedImage(image: image.value, size: imageRadius);
    }
    return RoundImage(imageCallback: image, size: imageRadius, child: child);
  }
}

/// A small level number over an avatar without an XP progress ring.
class AvatarLevelBadge extends StatelessWidget {
  const AvatarLevelBadge({
    super.key,
    required this.level,
    required this.avatar,
    this.radius = 17,
  });

  final int level;
  final Widget avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarDiameter = radius * 2;
    final dimension = avatarDiameter + 6;
    return Tooltip(
      excludeFromSemantics: true,
      message: 'Level $level',
      child: Semantics(
        excludeSemantics: true,
        label: 'Level $level',
        child: SizedBox.square(
          dimension: dimension,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              SizedBox.square(dimension: avatarDiameter, child: avatar),
              Positioned(
                left: 0,
                bottom: 0,
                child: _levelBadge(context, level: level, radius: radius),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The XP ring and level badge reserved for the signed-in user's top bar.
class UserXpAvatarIndicator extends StatelessWidget {
  const UserXpAvatarIndicator({
    super.key,
    required this.progress,
    required this.avatar,
    this.radius = 17,
  });

  final XpLevelProgress progress;
  final Widget avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final avatarDiameter = radius * 2;
    final dimension = avatarDiameter + 6;
    final strokeWidth = (radius * 0.15).clamp(1.5, 3.5);
    final levelProgressLabel = progress.xpToNextLevel == 0
        ? 'Level ${progress.level}, maximum level'
        : 'Level ${progress.level}, ${progress.xpIntoLevel} XP into this level, '
              '${progress.xpToNextLevel} XP to next level';

    return Tooltip(
      excludeFromSemantics: true,
      message: 'Level ${progress.level} · ${progress.totalXp} XP',
      child: Semantics(
        excludeSemantics: true,
        label: levelProgressLabel,
        child: SizedBox.square(
          dimension: dimension,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  end: progress.fraction.clamp(0, 1).toDouble(),
                ),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => SizedBox.square(
                  dimension: dimension,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: strokeWidth,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              SizedBox.square(dimension: avatarDiameter, child: avatar),
              Positioned(
                left: 0,
                bottom: 0,
                child: _levelBadge(
                  context,
                  level: progress.level,
                  radius: radius,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _levelBadge(
  BuildContext context, {
  required int level,
  required double radius,
}) {
  final theme = Theme.of(context);
  final badgeSize = (radius * 0.94).clamp(10.0, 20.0);
  return DecoratedBox(
    decoration: ShapeDecoration(
      color: theme.colorScheme.primary,
      shape: CircleBorder(
        side: BorderSide(
          color: theme.colorScheme.surfaceContainer,
          width: (radius * 0.09).clamp(1.0, 1.75),
        ),
      ),
    ),
    child: SizedBox.square(
      dimension: badgeSize,
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Text(
              '$level',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: (badgeSize * 0.5).clamp(5.0, 10.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
