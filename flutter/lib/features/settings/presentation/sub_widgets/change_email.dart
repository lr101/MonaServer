import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChangeEmailPage extends ConsumerStatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  ConsumerState<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends ConsumerState<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    if (_formKey.currentState!.validate()) {
      final userId = ref.read(userIdProvider);
      final result = await ref
          .read(userServiceProvider(userId).notifier)
          .changeUser(email: _newEmailController.text);
      if (!mounted) return;
      if (result != null) {
        CustomErrorSnackBar.message(
          message: result,
          type: CustomErrorSnackBarType.error,
        );
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Change email',
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
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'New email address',
                      border: OutlineInputBorder(),
                    ),
                    validator: LoginService.emailValidatorWithErrorMessage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionButton(
              label: 'Update email',
              icon: Icons.mail_outline,
              onPressed: _changeEmail,
            ),
          ],
        ),
      ),
    );
  }
}
