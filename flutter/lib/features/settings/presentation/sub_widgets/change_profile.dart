import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/features/settings/presentation/state/user_edit_state.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeProfile extends ConsumerStatefulWidget {
  const ChangeProfile({super.key});

  @override
  ConsumerState<ChangeProfile> createState() => _ChangeProfileState();
}

class _ChangeProfileState extends ConsumerState<ChangeProfile> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _originalDescription = '';
  String _originalUsername = '';
  bool _profileInitialized = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final user = currentUser.value;
    if (!_profileInitialized && user != null) {
      _originalDescription = user.description ?? '';
      _originalUsername = user.username;
      _descriptionController.text = _originalDescription;
      _usernameController.text = _originalUsername;
      _profileInitialized = true;
    }
    if (!_profileInitialized) {
      return SettingsPageScaffold(
        title: 'Edit profile',
        child: currentUser.hasError
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

    return SettingsPageScaffold(
      title: 'Edit profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: RoundImagePicker(
                      size: (MediaQuery.sizeOf(context).width / 4).clamp(
                        88.0,
                        112.0,
                      ),
                      editSize: 30,
                      imageUpload: (image) {
                        ref.read(userEditStateProvider.notifier).update(image);
                      },
                      imageCallback: AsyncData(
                        ref.watch(userEditStateProvider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: LoginService.userValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsPanel(
              child: Text(
                'You can change your username once every 14 days. '
                'A new profile picture may take up to 30 seconds to appear.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionButton(
              label: 'Update profile',
              icon: Icons.save_outlined,
              onPressed: () => _changeProfilePicture(ref, context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfilePicture(
    WidgetRef ref,
    BuildContext context,
  ) async {
    if (_formKey.currentState!.validate()) {
      final image = ref.read(userEditStateProvider);
      final userId = ref.read(userIdProvider);
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
          );
      if (result == null) {
        if (!context.mounted) return;
        CustomErrorSnackBar.message(
          message: "Successfully changed profile",
          type: CustomErrorSnackBarType.success,
        );
      } else {
        if (!context.mounted) return;
        CustomErrorSnackBar.message(message: result);
      }
    }
  }
}
