import 'dart:typed_data';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_cached_image.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A compact, consistently sized user or group avatar.
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
      return avatar;
    }

    return avatar;
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
    // Keep compact avatars at the same outside size as the top-bar progress
    // indicator, which reserves a 3 px margin around its image.
    final imageRadius = radius + 3;
    if (cachedImageOnly) {
      return RoundCachedImage(image: image.value, size: imageRadius);
    }
    return RoundImage(imageCallback: image, size: imageRadius, child: child);
  }
}

/// The XP ring and level badge reserved for the signed-in user's top bar.
class UserXpAvatarIndicator extends StatelessWidget {
  const UserXpAvatarIndicator({
    super.key,
    required XpLevelProgress progress,
    required this.avatar,
    this.radius = 17,
  }) : progress = progress,
       level = null,
       fraction = null;

  const UserXpAvatarIndicator.public({
    super.key,
    required this.level,
    required this.fraction,
    required this.avatar,
    this.radius = 17,
  }) : progress = null;

  final XpLevelProgress? progress;
  final int? level;
  final double? fraction;
  final Widget avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final displayLevel = progress?.level ?? level!;
    final progressFraction = progress?.fraction ?? fraction!;
    final avatarDiameter = radius * 2;
    final dimension = avatarDiameter + 6;
    final strokeWidth = (radius * 0.15).clamp(1.5, 3.5);
    final levelProgressLabel = progress == null
        ? 'Level $displayLevel, ${(progressFraction * 100).round()}% progress to next level'
        : _xpProgressLabel(progress!);

    return Tooltip(
      excludeFromSemantics: true,
      message: levelProgressLabel,
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
                  end: progressFraction.clamp(0, 1).toDouble(),
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
                      theme.colorScheme.primaryOnSurface,
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
                  level: displayLevel,
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

String _xpProgressLabel(XpLevelProgress progress) {
  final levelSpan = progress.xpIntoLevel + progress.xpToNextLevel;
  return progress.xpToNextLevel == 0
      ? 'Level ${progress.level}, ${progress.totalXp} total XP, maximum level'
      : 'Level ${progress.level}, ${progress.totalXp} total XP, '
            '${progress.xpIntoLevel} of $levelSpan XP into this level, '
            '${progress.xpToNextLevel} XP to next level';
}

Widget _levelBadge(
  BuildContext context, {
  required int level,
  required double radius,
}) {
  final theme = Theme.of(context);
  final badgeHeight = (radius * 0.70).clamp(12.0, 26.0);
  return DecoratedBox(
    key: const ValueKey('profile-level-badge'),
    decoration: ShapeDecoration(
      color: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: theme.colorScheme.surfaceContainer,
          width: (radius * 0.09).clamp(1.0, 1.75),
        ),
      ),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: badgeHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (radius * 0.09).clamp(2.0, 4.0),
          vertical: 1,
        ),
        child: Center(
          child: FittedBox(
            child: Text(
              'Lv $level',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontSize: (radius * 0.22).clamp(6.5, 9.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
