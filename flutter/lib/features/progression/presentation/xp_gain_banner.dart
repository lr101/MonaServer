import 'dart:async';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/xp_gain_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_gain_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double _navigationBarHeight = 80;
const double _navigationBarGap = 8;

/// Shows earned XP over the lower edge of the current route.
class XpGainBannerHost extends ConsumerStatefulWidget {
  const XpGainBannerHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<XpGainBannerHost> createState() => _XpGainBannerHostState();
}

class _XpGainBannerHostState extends ConsumerState<XpGainBannerHost> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    if (userId.isNotEmpty) ref.watch(userXpProvider(userId));
    final gains = ref.watch(xpGainsProvider);
    ref.listen(xpGainsProvider, (_, next) {
      _timer?.cancel();
      if (next.isNotEmpty && !MediaQuery.of(context).accessibleNavigation) {
        _timer = Timer(const Duration(seconds: 7), () {
          if (mounted) ref.read(xpGainsProvider.notifier).dismiss();
        });
      }
    });
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (gains.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: _navigationBarHeight + _navigationBarGap,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .3,
                  ),
                  child: SingleChildScrollView(
                    child: XpGainBanner(
                      gains: gains,
                      groupNames: {
                        for (final group
                            in ref.watch(userGroupServiceProvider).value ??
                                const <GroupEntity>[])
                          group.groupId: group.name,
                      },
                      onDismiss: () =>
                          ref.read(xpGainsProvider.notifier).dismiss(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class XpGainBanner extends StatelessWidget {
  const XpGainBanner({
    super.key,
    required this.gains,
    required this.onDismiss,
    this.groupNames = const {},
  });
  final List<XpGain> gains;
  final Map<String, String> groupNames;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'XP earned',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    for (final gain in gains)
                      Text(
                        '+${gain.amount} XP · ${gain.isGroup ? groupNames[gain.id] ?? 'Group' : 'You'} · Level ${gain.level}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              Semantics(
                label: 'Dismiss XP notification',
                button: true,
                child: IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
