import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

class GroupAchievementsCard extends StatelessWidget {
  const GroupAchievementsCard({
    super.key,
    required this.achievements,
    required this.group,
    this.designCatalog,
    this.groupImage,
    required this.currentUserId,
    required this.onClaimAchievement,
    required this.onPinStyleSelected,
    this.claimingAchievementId,
    this.updatingPinStyle = false,
  });

  final List<GroupAchievementsDtoInner> achievements;
  final GroupEntity? group;
  final GroupPinDesignCatalogDto? designCatalog;
  final Uint8List? groupImage;
  final String currentUserId;
  final Future<void> Function(int achievementId) onClaimAchievement;
  final Future<String?> Function(String style) onPinStyleSelected;
  final int? claimingAchievementId;
  final bool updatingPinStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedAchievements = [...achievements]
      ..sort((a, b) {
        if (a.claimable != b.claimable) return a.claimable ? -1 : 1;
        if (a.claimed != b.claimed) return a.claimed ? 1 : -1;
        final trackOrder = a.track?.compareTo(b.track ?? '') ?? 0;
        return trackOrder == 0
            ? a.thresholdValue.compareTo(b.thresholdValue)
            : trackOrder;
      });
    final claimedStyles = achievements
        .where((achievement) => achievement.claimed)
        .map((achievement) => achievement.rewardPinStyle.value)
        .toSet();
    final isAdmin = group?.groupAdmin == currentUserId;

    return Semantics(
      container: true,
      label: 'Group achievements and shared pin appearance',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < sortedAchievements.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _AchievementRow(
                achievement: sortedAchievements[index],
                canClaim: group?.userIsMember == true,
                isClaiming:
                    claimingAchievementId ==
                    sortedAchievements[index].achievementId,
                onClaim: () =>
                    onClaimAchievement(sortedAchievements[index].achievementId),
              ),
            ],
            if (isAdmin && claimedStyles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 12),
              Text(
                'Pin appearance',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an earned shape and color combination for group pins.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: _PinDesignPreview(
                  style: group?.pinStyle ?? 'classic',
                  designCatalog: designCatalog,
                  groupImage: groupImage,
                  width: 58,
                  height: 66,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      'classic',
                      ..._pinStyles.where(claimedStyles.contains),
                    ].map((style) {
                      final selected = group?.pinStyle == style;
                      return ChoiceChip(
                        avatar: _PinDesignPreview(
                          style: style,
                          designCatalog: designCatalog,
                          groupImage: groupImage,
                          width: 26,
                          height: 32,
                        ),
                        label: Text(_styleName(style)),
                        selected: selected,
                        onSelected: updatingPinStyle || selected
                            ? null
                            : (_) => onPinStyleSelected(style),
                      );
                    }).toList(),
              ),
              if (updatingPinStyle) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ] else if (!isAdmin && group != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _PinDesignPreview(
                    style: group!.pinStyle,
                    designCatalog: designCatalog,
                    groupImage: groupImage,
                    width: 30,
                    height: 36,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Group pin appearance: ${_styleName(group!.pinStyle)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _pinStyles = ['moss', 'sunset', 'aurora'];

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.canClaim,
    required this.isClaiming,
    required this.onClaim,
  });

  final GroupAchievementsDtoInner achievement;
  final bool canClaim;
  final bool isClaiming;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final progress = achievement.thresholdValue <= 0
        ? 0.0
        : (achievement.currentValue / achievement.thresholdValue).clamp(
            0.0,
            1.0,
          );
    return AchievementCard(
      title: achievement.name ?? 'Group pin milestone',
      description: achievement.description ?? '',
      currentValue: achievement.currentValue,
      thresholdValue: achievement.thresholdValue,
      progress: progress,
      claimed: achievement.claimed,
      claimable: achievement.claimable && canClaim,
      onTap: achievement.claimable && canClaim && !isClaiming ? onClaim : null,
    );
  }
}

class _PinDesignPreview extends StatelessWidget {
  const _PinDesignPreview({
    required this.style,
    required this.designCatalog,
    required this.groupImage,
    required this.width,
    required this.height,
  });

  final String style;
  final GroupPinDesignCatalogDto? designCatalog;
  final Uint8List? groupImage;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final design = MapPinDesign.forCatalog(designCatalog, style);
    return SizedBox(
      width: width,
      height: height,
      child: PinMarkerImage(
        isGone: false,
        style: style,
        design: design,
        image: groupImage == null
            ? ColoredBox(
                color: design.bodyColor,
                child: Center(
                  child: Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: width * .34,
                  ),
                ),
              )
            : Image.memory(
                groupImage!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}

String _styleName(String style) => switch (style) {
  'moss' => 'Moss',
  'sunset' => 'Sunset',
  'aurora' => 'Aurora',
  _ => 'Classic',
};
