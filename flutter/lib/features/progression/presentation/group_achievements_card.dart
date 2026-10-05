import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_tier_carousel.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

class GroupAchievementsCard extends StatefulWidget {
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
  State<GroupAchievementsCard> createState() => _GroupAchievementsCardState();
}

class _GroupAchievementsCardState extends State<GroupAchievementsCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracks = _groupAchievementTracks
        .map(
          (track) => _GroupAchievementTrack(
            id: track.id,
            title: track.title,
            achievements:
                widget.achievements
                    .where((achievement) => achievement.track == track.id)
                    .toList()
                  ..sort((a, b) {
                    final threshold = a.thresholdValue.compareTo(
                      b.thresholdValue,
                    );
                    return threshold == 0
                        ? a.achievementId.compareTo(b.achievementId)
                        : threshold;
                  }),
          ),
        )
        .where((track) => track.achievements.isNotEmpty)
        .toList();
    final claimedStyles = widget.achievements
        .where((achievement) => achievement.claimed)
        .map((achievement) => achievement.rewardPinStyle?.value)
        .whereType<String>()
        .toSet();
    final group = widget.group;
    final isAdmin = group?.groupAdmin == widget.currentUserId;

    return Semantics(
      container: true,
      label: 'Group achievements and shared pin appearance',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group achievements',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No group achievements yet.'),
              )
            else
              for (
                var trackIndex = 0;
                trackIndex < tracks.length;
                trackIndex++
              ) ...[
                if (trackIndex > 0) const SizedBox(height: 12),
                Text(
                  tracks[trackIndex].title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                AchievementTierCarousel(
                  key: ValueKey(tracks[trackIndex].id),
                  title: tracks[trackIndex].title,
                  tierCount: tracks[trackIndex].achievements.length,
                  initialPage: activeAchievementTierIndex(
                    tracks[trackIndex].achievements,
                    (achievement) => achievement.claimed,
                  ),
                  itemBuilder: (context, tierIndex) {
                    final achievement =
                        tracks[trackIndex].achievements[tierIndex];
                    return _AchievementRow(
                      achievement: achievement,
                      designCatalog: widget.designCatalog,
                      groupImage: widget.groupImage,
                      canClaim: group?.userIsMember == true,
                      isClaiming:
                          widget.claimingAchievementId ==
                          achievement.achievementId,
                      onClaim: () =>
                          widget.onClaimAchievement(achievement.achievementId),
                    );
                  },
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
                  designCatalog: widget.designCatalog,
                  groupImage: widget.groupImage,
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
                          designCatalog: widget.designCatalog,
                          groupImage: widget.groupImage,
                          width: 26,
                          height: 32,
                        ),
                        label: Text(_styleName(style)),
                        selected: selected,
                        onSelected: widget.updatingPinStyle || selected
                            ? null
                            : (_) => widget.onPinStyleSelected(style),
                      );
                    }).toList(),
              ),
              if (widget.updatingPinStyle) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ] else if (!isAdmin && group != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _PinDesignPreview(
                    style: group.pinStyle,
                    designCatalog: widget.designCatalog,
                    groupImage: widget.groupImage,
                    width: 30,
                    height: 36,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Group pin appearance: ${_styleName(group.pinStyle)}',
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

const _groupAchievementTracks = <_GroupAchievementTrackDefinition>[
  _GroupAchievementTrackDefinition('active_pins', 'Pins'),
  _GroupAchievementTrackDefinition('contributors', 'Contributors'),
  _GroupAchievementTrackDefinition('members', 'Members'),
  _GroupAchievementTrackDefinition('photo_updates', 'Photo updates'),
  _GroupAchievementTrackDefinition('gone_pins', 'Gone pins'),
];

class _GroupAchievementTrackDefinition {
  const _GroupAchievementTrackDefinition(this.id, this.title);

  final String id;
  final String title;
}

class _GroupAchievementTrack {
  const _GroupAchievementTrack({
    required this.id,
    required this.title,
    required this.achievements,
  });

  final String id;
  final String title;
  final List<GroupAchievementsDtoInner> achievements;
}

const _pinStyles = [
  'moss',
  'sunset',
  'aurora',
  'seafoam',
  'honey',
  'orchid',
  'copper',
  'jade',
  'ember',
  'glacier',
  'rose',
  'midnight',
];

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.designCatalog,
    required this.groupImage,
    required this.canClaim,
    required this.isClaiming,
    required this.onClaim,
  });

  final GroupAchievementsDtoInner achievement;
  final GroupPinDesignCatalogDto? designCatalog;
  final Uint8List? groupImage;
  final bool canClaim;
  final bool isClaiming;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = achievement.thresholdValue <= 0
        ? 0.0
        : (achievement.currentValue / achievement.thresholdValue).clamp(
            0.0,
            1.0,
          );
    final style = achievement.rewardPinStyle?.value;
    final rewardType =
        achievement.rewardType?.value ??
        _groupRewardType(achievement.difficulty?.value);
    final rewardDescription = switch (rewardType) {
      'xp' => '${achievement.rewardXp ?? 50} group XP',
      'color' => '${style == null ? 'Group pin' : _styleName(style)} color',
      _ =>
        '${_groupRewardRarity(achievement.difficulty?.value)} ${style == null ? 'pin' : _styleName(style)} badge design',
    };
    final reward = switch (rewardType) {
      'xp' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 15, color: theme.colorScheme.primaryOnSurface),
          const SizedBox(width: 4),
          Text('${achievement.rewardXp ?? 50} Group XP'),
        ],
      ),
      'color' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (achievement.rewardColor != null)
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: Color(
                  0xFF000000 |
                      int.parse(
                        achievement.rewardColor!.substring(1),
                        radix: 16,
                      ),
                ),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${style == null ? 'Group pin' : _styleName(style)} color',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PinDesignPreview(
            style: style ?? 'classic',
            designCatalog: designCatalog,
            groupImage: groupImage,
            width: 19,
            height: 23,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              rewardDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    };
    return AchievementCard(
      title: achievement.name ?? 'Group pin milestone',
      description: achievement.description ?? '',
      currentValue: achievement.currentValue,
      thresholdValue: achievement.thresholdValue,
      progress: progress,
      claimed: achievement.claimed,
      claimable: achievement.claimable && canClaim,
      rewardDescription: rewardDescription,
      reward: reward,
      onTap: achievement.claimable && canClaim && !isClaiming ? onClaim : null,
    );
  }
}

String _groupRewardType(String? difficulty) => switch (difficulty) {
  'hard' => 'badge',
  'medium' => 'color',
  _ => 'xp',
};

String _groupRewardRarity(String? difficulty) => switch (difficulty) {
  'hard' => 'Mythic',
  'medium' => 'Rare',
  _ => 'Signature',
};

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
  'seafoam' => 'Seafoam',
  'honey' => 'Honey',
  'orchid' => 'Orchid',
  'copper' => 'Copper',
  'jade' => 'Jade',
  'ember' => 'Ember',
  'glacier' => 'Glacier',
  'rose' => 'Rose',
  'midnight' => 'Midnight',
  _ => 'Classic',
};
