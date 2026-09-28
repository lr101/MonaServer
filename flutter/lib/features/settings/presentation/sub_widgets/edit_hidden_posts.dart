import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditHiddenPosts extends ConsumerWidget {
  const EditHiddenPosts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
    return SettingsPageScaffold(
      title: 'Hidden posts',
      child: hiddenPosts.isEmpty
          ? const SettingsEmptyState(
              icon: Icons.hide_image_outlined,
              title: 'No hidden posts',
              description:
                  'Posts you hide from the map and feed will appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hidden posts are removed from your map and feed. '
                  'Remove one here to see it again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final pinId in hiddenPosts) ...[
                  SettingsPanel(
                    padding: 8,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.image_outlined),
                      ),
                      title: const Text('Hidden artwork'),
                      subtitle: Text(
                        'Pin ID: ${_shortId(pinId)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Show this post again',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => _removePost(context, ref, pinId),
                      ),
                      onTap: () => _removePost(context, ref, pinId),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  static String _shortId(String id) =>
      id.length <= 12 ? id : '${id.substring(0, 8)}…';

  Future<void> _removePost(
    BuildContext context,
    WidgetRef ref,
    String pinId,
  ) async {
    final confirmed = await confirmSettingsAction(
      context,
      title: 'Show this post again?',
      message: 'This artwork will return to your map and feed.',
      actionLabel: 'Show post',
    );
    if (confirmed) {
      ref.read(hiddenPostsServiceProvider.notifier).removeHiddenPost(pinId);
    }
  }
}
