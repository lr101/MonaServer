import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_tier_carousel.dart';
import 'package:flutter/material.dart';

class AchievementTrackData<T> {
  const AchievementTrackData({
    required this.id,
    required this.title,
    required this.tiers,
  });
  final String id;
  final String title;
  final List<T> tiers;
}

IconData achievementTrackIcon(String id) => switch (id) {
  'sticks' || 'active_pins' => Icons.add_location_alt_outlined,
  'photos' => Icons.photo_library_outlined,
  'updates' || 'photo_updates' => Icons.add_photo_alternate_outlined,
  'gone_pins' => Icons.visibility_off_outlined,
  'places' => Icons.public,
  'groups' || 'members' => Icons.groups_outlined,
  'contributors' || 'contributing_groups' => Icons.person_add_alt,
  _ => Icons.favorite_outline,
};

/// Current goals first, with an explicit catalog of every tier.
class AchievementTrackBrowser<T> extends StatefulWidget {
  const AchievementTrackBrowser({
    super.key,
    required this.tracks,
    this.title = 'Achievements',
    required this.tierBuilder,
    required this.isClaimed,
    required this.isReady,
    required this.progress,
  });
  final List<AchievementTrackData<T>> tracks;
  final String title;
  final Widget Function(BuildContext context, T tier) tierBuilder;
  final bool Function(T tier) isClaimed;
  final bool Function(T tier) isReady;
  final double Function(T tier) progress;
  @override
  State<AchievementTrackBrowser<T>> createState() =>
      _AchievementTrackBrowserState<T>();
}

class _AchievementTrackBrowserState<T>
    extends State<AchievementTrackBrowser<T>> {
  String? _trackId;
  T _active(AchievementTrackData<T> track) =>
      track.tiers[activeAchievementTierIndex(track.tiers, widget.isClaimed)];
  int _priority(AchievementTrackData<T> track) => widget.isReady(_active(track))
      ? 0
      : track.tiers.every(widget.isClaimed)
      ? 2
      : 1;
  Widget _tier(AchievementTrackData<T> track, T tier) => AchievementTrackScope(
    icon: achievementTrackIcon(track.id),
    title: track.title,
    child: Builder(builder: (context) => widget.tierBuilder(context, tier)),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
  List<Widget> _rows(List<AchievementTrackData<T>> tracks) => [
    for (final track in tracks)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _tier(track, _active(track)),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final available = widget.tracks.where((t) => t.tiers.isNotEmpty).toList();
    if (available.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No achievements yet.')),
      );
    }
    final tracks = [...available]
      ..sort((a, b) {
        final p = _priority(a).compareTo(_priority(b));
        if (p != 0) return p;
        final progress = widget
            .progress(_active(b))
            .compareTo(widget.progress(_active(a)));
        return progress != 0
            ? progress
            : available.indexOf(a).compareTo(available.indexOf(b));
      });
    final selected = available.where((t) => t.id == _trackId).firstOrNull;
    final ready = tracks.where((t) => _priority(t) == 0).toList();
    final next = tracks.where((t) => _priority(t) == 1).toList();
    final collected = tracks.where((t) => _priority(t) == 2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (selected != null)
              IconButton(
                tooltip: 'All achievement tracks',
                onPressed: () => setState(() => _trackId = null),
                icon: const Icon(Icons.arrow_back),
              ),
            Expanded(
              child: Text(
                selected?.title ?? widget.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Semantics(
              button: true,
              container: true,
              child: PopupMenuButton<String>(
                tooltip: 'Browse all achievement tiers',
                onSelected: (id) => setState(() => _trackId = id),
                itemBuilder: (_) => [
                  for (final t in available)
                    PopupMenuItem(value: t.id, child: Text(t.title)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_list_outlined, size: 20),
                        if (MediaQuery.textScalerOf(context).scale(14) <=
                            20) ...[
                          const SizedBox(width: 6),
                          const Text('All tiers'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selected != null) ...[
          for (final tier in selected.tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _tier(selected, tier),
            ),
        ] else ...[
          if (ready.isNotEmpty) ...[
            _heading('Ready to collect'),
            ..._rows(ready),
          ],
          if (next.isNotEmpty) ...[_heading('Next up'), ..._rows(next)],
          if (collected.isNotEmpty) ...[
            _heading('Collected'),
            ..._rows(collected),
          ],
        ],
      ],
    );
  }
}
