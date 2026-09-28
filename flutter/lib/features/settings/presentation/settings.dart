import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/features/settings/presentation/state/notification_state.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:buff_lisa/util/theme/service/theme_state.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';

class Settings extends ConsumerWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeStateProvider);
    final notificationState = ref.watch(notificationStateProvider);
    final notificationsEnabled = notificationState.value ?? false;
    final notificationSubtitle = notificationState.when(
      data: (_) => 'Choose whether Stick-It can send notifications.',
      loading: () => 'Checking notification permission…',
      error: (_, _) => 'Notification permission is unavailable.',
    );

    return SettingsPageScaffold(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionCard(
            title: 'Appearance',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark appearance'),
                subtitle: const Text('Use a dark color scheme'),
                value: themeMode == ThemeMode.dark,
                onChanged: (isDark) =>
                    ref.read(themeStateProvider.notifier).setTheme(!isDark),
              ),
              const ListTile(
                leading: Icon(Icons.language_outlined),
                title: Text('Language'),
                subtitle: Text('English'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: 'Notifications',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('All notifications'),
                subtitle: Text(notificationSubtitle),
                value: notificationsEnabled,
                onChanged: notificationState.isLoading
                    ? null
                    : (enabled) => ref
                          .read(notificationStateProvider.notifier)
                          .updatePermission(enabled),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: 'Account',
            children: [
              _navigationTile(
                context,
                icon: Icons.person_outline,
                title: 'Edit profile',
                routeName: 'profileSettings',
              ),
              _navigationTile(
                context,
                icon: Icons.lock_outline,
                title: 'Change password',
                routeName: 'pswSettings',
              ),
              _navigationTile(
                context,
                icon: Icons.mail_outline,
                title: 'Change email',
                routeName: 'emailSettings',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: 'Privacy & data',
            children: [
              _navigationTile(
                context,
                icon: Icons.hide_image_outlined,
                title: 'Hidden posts',
                routeName: 'hiddenPostSettings',
              ),
              _navigationTile(
                context,
                icon: Icons.person_off_outlined,
                title: 'Hidden users',
                routeName: 'hiddenUserSettings',
              ),
              ListTile(
                leading: const Icon(Icons.cached_outlined),
                title: const Text('Delete cache'),
                subtitle: const Text('Refresh app data on this device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _confirmDeleteCache(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Contact developer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(
                  'report',
                  extra: ['Bug', 'Feature Request', 'Other'],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openPolicy(
                  context,
                  ref,
                  'Privacy Policy',
                  '/public/privacy-policy',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openPolicy(
                  context,
                  ref,
                  'Terms of Service',
                  '/public/agb',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('OpenStreetMap attribution'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => context.pushNamed(
                  'web',
                  queryParameters: {
                    'url': 'https://www.openstreetmap.org/copyright',
                    'title': 'OpenStreetMap attribution',
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Follow Stick-It'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _socialButton(
                        tooltip: 'Discord',
                        icon: const FaIcon(FontAwesomeIcons.discord),
                        onPressed: () =>
                            clickedOnLink(dotenv.env['DISCORD_INVITE']),
                      ),
                      _socialButton(
                        tooltip: 'Instagram',
                        icon: const FaIcon(FontAwesomeIcons.instagram),
                        onPressed: () =>
                            clickedOnLink(dotenv.env['INSTAGRAM_URL']),
                      ),
                      _socialButton(
                        tooltip: 'GitHub',
                        icon: const FaIcon(FontAwesomeIcons.github),
                        onPressed: () =>
                            clickedOnLink(dotenv.env['URL_GITHUB_REPO']),
                      ),
                      _socialButton(
                        tooltip: 'Rate Stick-It',
                        icon: const Icon(Icons.star_border),
                        onPressed: () => InAppReview.instance.openStoreListing(
                          appStoreId: dotenv.env['APPSTORE_ID'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            title: 'Session',
            children: [
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete account',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text(
                  'Permanently remove your account and data',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('deleteSettings'),
              ),
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: const Text('Log out'),
                subtitle: const Text('Sign out on this device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => CustomDialog(
                    title: 'Log out?',
                    text2: 'Log out',
                    text1: 'Cancel',
                    onPressed: () => context.goNamed('logout'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String routeName,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.pushNamed(routeName),
  );

  Widget _socialButton({
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
  }) => Tooltip(
    message: tooltip,
    child: IconButton.filledTonal(
      onPressed: onPressed,
      icon: icon,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    ),
  );

  void _openPolicy(
    BuildContext context,
    WidgetRef ref,
    String title,
    String path,
  ) {
    final host = ref.read(globalDataServiceProvider).host;
    context.pushNamed(
      'web',
      queryParameters: {'url': '$host$path', 'title': title},
    );
  }

  Future<void> _confirmDeleteCache(BuildContext context) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('Delete cached app data?'),
        content: const Text(
          'This signs you out and refreshes data on this device. Any posts '
          'that have not synced to the server will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete cache'),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      context.goNamed('logout', extra: true);
    }
  }
}
