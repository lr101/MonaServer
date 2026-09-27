import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditHiddenUsers extends ConsumerWidget {
  const EditHiddenUsers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenUsers = ref.watch(hiddenUserServiceProvider);
    return SettingsPageScaffold(
      title: 'Hidden users',
      child: hiddenUsers.isEmpty
          ? const SettingsEmptyState(
              icon: Icons.person_off_outlined,
              title: 'No hidden users',
              description:
                  'Users you hide from the map and feed will appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Remove a user from this list to see their posts again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SettingsSectionCard(
                  title: 'Hidden users · ${hiddenUsers.length}',
                  children: [
                    for (final userId in hiddenUsers)
                      _HiddenUserTile(userId: userId),
                  ],
                ),
              ],
            ),
    );
  }
}

class _HiddenUserTile extends ConsumerWidget {
  const _HiddenUserTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(userByIdUsernameProvider(userId));
    return ListTile(
      leading: SmallProfilePicture.user(userId: userId, radius: 22),
      title: Text(username.value ?? 'Hidden user'),
      subtitle: username.isLoading ? null : const Text('Posts are hidden'),
      trailing: IconButton(
        tooltip: 'Show this user’s posts again',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => _remove(context, ref),
      ),
      onTap: () => _remove(context, ref),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmSettingsAction(
      context,
      title: 'Show this user again?',
      message: 'Their posts will return to your map and feed.',
      actionLabel: 'Show user',
    );
    if (confirmed) {
      ref.read(hiddenUserServiceProvider.notifier).removeHiddenUser(userId);
    }
  }
}
