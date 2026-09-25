import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

class GroupAchievementsCard extends StatelessWidget {
  const GroupAchievementsCard({
    super.key,
    required this.achievements,
    required this.group,
    required this.currentUserId,
    required this.onClaimAchievement,
    required this.onPinStyleSelected,
    this.claimingAchievementId,
    this.celebratingAchievementId,
    this.updatingPinStyle = false,
  });

  final List<GroupAchievementsDtoInner> achievements;
  final GroupEntity? group;
  final String currentUserId;
  final Future<void> Function(int achievementId) onClaimAchievement;
  final Future<String?> Function(String style) onPinStyleSelected;
  final int? claimingAchievementId;
  final int? celebratingAchievementId;
  final bool updatingPinStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
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
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group achievements',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Earn shared frames for your group pins.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < sortedAchievements.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(height: 8),
                _AchievementRow(
                  achievement: sortedAchievements[index],
                  canClaim: group?.userIsMember == true,
                  reduceMotion: reduceMotion,
                  isClaiming:
                      claimingAchievementId ==
                      sortedAchievements[index].achievementId,
                  isCelebrating:
                      celebratingAchievementId ==
                      sortedAchievements[index].achievementId,
                  onClaim: () => onClaimAchievement(
                    sortedAchievements[index].achievementId,
                  ),
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
                  'Choose a frame shared by all group pins.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                          avatar: _StyleSwatch(style: style, size: 14),
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
                    _StyleSwatch(style: group!.pinStyle, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Group pin frame: ${_styleName(group!.pinStyle)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
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
    required this.reduceMotion,
    required this.isClaiming,
    required this.isCelebrating,
    required this.onClaim,
  });

  final GroupAchievementsDtoInner achievement;
  final bool canClaim;
  final bool reduceMotion;
  final bool isClaiming;
  final bool isCelebrating;
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
    final noun = achievement.track == 'active_pins' ? 'active pins' : 'pins';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StyleSwatch(style: achievement.rewardPinStyle.value, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.name ?? 'Group pin milestone',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.description ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_styleName(achievement.rewardPinStyle.value)} frame reward',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (achievement.claimed)
                _ClaimedBadge(
                  animate: isCelebrating,
                  reduceMotion: reduceMotion,
                )
              else if (achievement.claimable)
                if (!canClaim)
                  Text(
                    'Join to claim',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: isClaiming ? null : onClaim,
                    child: isClaiming
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Claim'),
                  )
              else
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _styleColor(theme, achievement.rewardPinStyle.value),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${achievement.currentValue} / ${achievement.thresholdValue} $noun',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaimedBadge extends StatelessWidget {
  const _ClaimedBadge({required this.animate, required this.reduceMotion});

  final bool animate;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = DecoratedBox(
      key: const ValueKey('claimed-achievement'),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.check_rounded,
          size: 18,
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );

    if (!animate || reduceMotion) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.65, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({required this.style, required this.size});

  final String style;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: ValueKey('pin-style-frame-$style'),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: _styleColor(Theme.of(context), style),
        width: 2,
      ),
    ),
    child: SizedBox.square(dimension: size),
  );
}

Color _styleColor(ThemeData theme, String style) => switch (style) {
  'moss' => const Color(0xff668465),
  'sunset' => const Color(0xffd57b50),
  'aurora' => const Color(0xff6d77ba),
  _ => theme.colorScheme.outline,
};

String _styleName(String style) => switch (style) {
  'moss' => 'Moss',
  'sunset' => 'Sunset',
  'aurora' => 'Aurora',
  _ => 'Classic',
};
