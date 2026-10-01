import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/features/settings/presentation/state/user_edit_state.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image_picker.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class ChangeProfile extends ConsumerStatefulWidget {
  const ChangeProfile({super.key});

  @override
  ConsumerState<ChangeProfile> createState() => _ChangeProfileState();
}

class _ChangeProfileState extends ConsumerState<ChangeProfile> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _formInitialized = false;
  String _originalDescription = '';
  String _originalUsername = '';
  int? _originalBadge;
  int? _selectedBadge;
  String _originalBadgeColor = 'default';
  String _selectedBadgeColor = 'default';

  @override
  void dispose() {
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserState = ref.watch(currentUserProvider);
    final currentUser = currentUserState.value;
    if (!_formInitialized && currentUser != null) {
      _initializeForm(currentUser);
    }
    if (!_formInitialized) {
      return SettingsPageScaffold(
        title: 'Edit profile',
        child: currentUserState.hasError
            ? const SettingsEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile unavailable',
                description:
                    'Your profile could not be loaded. Please try again.',
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
      );
    }
    final achievements = ref.watch(achievementsProvider);

    return SettingsPageScaffold(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoCard(context),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeading(
                    context,
                    icon: Icons.person_outline,
                    title: 'Your details',
                    subtitle: 'Choose how people see you around Stick-It.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                      helperText: 'You can change it every 14 days.',
                    ),
                    validator: LoginService.userValidator,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'About you',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeading(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Profile badge',
                    subtitle: 'Choose a badge earned from a hard achievement.',
                  ),
                  const SizedBox(height: 16),
                  _buildBadgeChoices(context, achievements),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeading(
                    context,
                    icon: Icons.palette_outlined,
                    title: 'Badge color',
                    subtitle: 'Colors earned from medium achievements customize your badge.',
                  ),
                  const SizedBox(height: 16),
                  _buildBadgeColorChoices(context, achievements),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionButton(
              label: 'Save changes',
              icon: Icons.check,
              onPressed: () => _saveProfile(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Change profile picture',
              child: Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer.withValues(alpha: 0.24),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.75),
                    width: 2,
                  ),
                ),
                child: RoundImagePicker(
                  size: 36,
                  editSize: 14,
                  editOffset: const Offset(6, 6),
                  imageUpload: (image) {
                    ref.read(userEditStateProvider.notifier).update(image);
                  },
                  imageCallback: AsyncData(ref.watch(userEditStateProvider)),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Tap the pencil to choose a photo for your profile.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (_selectedBadge != null) ...[
                    const SizedBox(height: 10),
                    Batch(
                      batchId: _selectedBadge!,
                      fontSize: 11,
                      colorOverride: _selectedBadgeColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) =>
      SettingsPanel(padding: 18, child: child);

  Widget _buildSectionHeading(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withValues(alpha: 0.16),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _initializeForm(UserEntity user) {
    _formInitialized = true;
    _originalDescription = user.description ?? '';
    _originalUsername = user.username;
    _descriptionController.text = _originalDescription;
    _usernameController.text = _originalUsername;
    _originalBadge = user.selectedBatch;
    _selectedBadge = user.selectedBatch;
    _originalBadgeColor = user.selectedBatchColor ?? 'default';
    _selectedBadgeColor = _originalBadgeColor;
  }

  Widget _buildBadgeChoices(
    BuildContext context,
    AsyncValue<List<UserAchievementsDtoInner>> achievements,
  ) {
    return achievements.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stackTrace) => _achievementLoadError(),
      data: (items) {
        final earnedBadges = items
            .where(
              (item) =>
                  item.claimed &&
                  ((item.rewardType?.value ?? 'badge') == 'badge'),
            )
            .toList();
        final selectedIsListed = earnedBadges.any(
          (item) => item.achievementId == _selectedBadge,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (earnedBadges.isEmpty && _selectedBadge == null)
              _buildRewardHint(
                context,
                icon: Icons.lock_outline,
                message: 'Claim an achievement to unlock a badge.',
              ),
            if (earnedBadges.isEmpty && _selectedBadge == null)
              const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in earnedBadges)
                  ChoiceChip(
                    label: Batch(
                      batchId: item.achievementId,
                      colorOverride: _selectedBadgeColor,
                    ),
                    selected: _selectedBadge == item.achievementId,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedBadge = item.achievementId);
                      }
                    },
                  ),
                if (_selectedBadge != null && !selectedIsListed)
                  ChoiceChip(
                    label: Batch(
                      batchId: _selectedBadge!,
                      colorOverride: _selectedBadgeColor,
                    ),
                    selected: true,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadgeColorChoices(
    BuildContext context,
    AsyncValue<List<UserAchievementsDtoInner>> achievements,
  ) {
    return achievements.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stackTrace) => _achievementLoadError(),
      data: (items) {
        final unlockedColors = <String>{
          for (final item in items)
            if (item.claimed && item.rewardColor != null) item.rewardColor!,
          if (_originalBadgeColor != 'default') _originalBadgeColor,
        }.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.format_color_reset, size: 18),
                  label: const Text('Default'),
                  selected: _selectedBadgeColor == 'default',
                  onSelected: (_) =>
                      setState(() => _selectedBadgeColor = 'default'),
                ),
                for (final color in unlockedColors)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 9,
                      backgroundColor: _colorFromHex(color),
                    ),
                    label: Text(_batchColorName(color)),
                    selected: _selectedBadgeColor == color,
                    onSelected: (_) =>
                        setState(() => _selectedBadgeColor = color),
                  ),
              ],
            ),
            if (unlockedColors.isEmpty) ...[
              const SizedBox(height: 12),
              _buildRewardHint(
                context,
                icon: Icons.auto_awesome_outlined,
                message: 'Earn color rewards from medium achievements to unlock more.',
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _achievementLoadError() => Row(
    children: [
      const Expanded(child: Text('Achievement rewards could not be loaded.')),
      IconButton(
        tooltip: 'Reload achievements',
        onPressed: () => ref.invalidate(achievementsProvider),
        icon: const Icon(Icons.refresh),
      ),
    ],
  );

  Widget _buildRewardHint(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(userIdProvider);
    final image = ref.read(userEditStateProvider);
    final result = await ref
        .read(userServiceProvider(userId).notifier)
        .changeUser(
          username: _originalUsername == _usernameController.text
              ? null
              : _usernameController.text,
          description: _originalDescription == _descriptionController.text
              ? null
              : _descriptionController.text,
          profilePicture: ref.read(userEditStateProvider.notifier).hasChanged
              ? image
              : null,
          selectedBatch: _selectedBadge == _originalBadge
              ? null
              : _selectedBadge,
          selectedBatchColor: _selectedBadgeColor == _originalBadgeColor
              ? null
              : _selectedBadgeColor,
        );
    if (!mounted) return;
    CustomErrorSnackBar.message(
      message: result ?? 'Successfully changed profile',
      type: result == null
          ? CustomErrorSnackBarType.success
          : CustomErrorSnackBarType.error,
    );
  }
}

Color _colorFromHex(String value) =>
    Color(int.parse(value.substring(1), radix: 16));

String _batchColorName(String color) => switch (color) {
  '#FF7CB342' => 'Leaf green',
  '#FFE53935' => 'Ruby',
  '#FFC62828' => 'Crimson',
  '#FF26A69A' => 'Sea teal',
  '#FFD81B60' => 'Magenta',
  '#FFC2185B' => 'Raspberry',
  '#FFEF6C00' => 'Burnt orange',
  '#FFFF5722' => 'Deep orange',
  '#FFD4E157' => 'Lime',
  '#FF8BC34A' => 'Light green',
  '#FFFF5252' => 'Red',
  '#FF64FFDA' => 'Teal',
  '#FFE91E63' => 'Pink',
  '#FFFF9800' => 'Orange',
  '#FF2196F3' => 'Blue',
  '#FFFF7043' => 'Coral',
  '#FF673AB7' => 'Violet',
  '#FF00ACC1' => 'Cyan',
  '#FF9C27B0' => 'Purple',
  '#FF7B1FA2' => 'Amethyst',
  '#FFFFC107' => 'Amber',
  '#FF3F51B5' => 'Indigo',
  '#FF795548' => 'Brown',
  _ => 'Custom',
};
