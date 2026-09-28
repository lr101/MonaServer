import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChangePassword extends ConsumerStatefulWidget {
  const ChangePassword({super.key});

  @override
  ConsumerState<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePassword> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Change password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureCurrentPassword
                            ? 'Show current password'
                            : 'Hide current password',
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureCurrentPassword =
                              !_obscureCurrentPassword,
                        ),
                      ),
                    ),
                    validator: LoginService.passwordValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureNewPassword
                            ? 'Show new password'
                            : 'Hide new password',
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                      ),
                    ),
                    validator: LoginService.passwordValidator,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Show confirmation password'
                            : 'Hide confirmation password',
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    validator: _validateConfirmPassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionButton(
              label: 'Update password',
              icon: Icons.lock_reset_outlined,
              onPressed: _changePassword,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (_formKey.currentState!.validate()) {
      final userId = ref.read(userIdProvider);
      final result = await ref
          .read(userServiceProvider(userId).notifier)
          .changeUser(password: _newPasswordController.text);
      if (!mounted) return;
      if (result == null && mounted) {
        context.pop();
      } else if (result != null) {
        CustomErrorSnackBar.message(
          message: result,
          type: CustomErrorSnackBarType.error,
        );
      }
    }
  }
}
