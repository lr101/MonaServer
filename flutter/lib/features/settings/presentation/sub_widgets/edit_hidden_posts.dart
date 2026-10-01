import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                  _HiddenPostTile(
                    pinId: pinId,
                    onRestore: () => _removePost(context, ref, pinId),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

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

class _HiddenPostTile extends ConsumerWidget {
  const _HiddenPostTile({required this.pinId, required this.onRestore});

  final String pinId;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pinImageForDetailsProvider(pinId)).value;
    final colors = Theme.of(context).colorScheme;

    return SettingsPanel(
      padding: 8,
      child: ListTile(
        leading: SizedBox.square(
          dimension: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image == null
                ? ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  )
                : Image.memory(
                    image,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ),
        title: const Text('Hidden artwork'),
        subtitle: const Text('Tap to view this artwork'),
        trailing: IconButton(
          tooltip: 'Show this post again',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: onRestore,
        ),
        onTap: () =>
            context.pushNamed('viewImage', pathParameters: {'id': pinId}),
      ),
    );
  }
}
