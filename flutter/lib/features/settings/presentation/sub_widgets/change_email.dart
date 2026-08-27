import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
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


  Future<void> _changeEmail() async {
    if (_formKey.currentState!.validate()) {
      final userId = ref.watch(userIdProvider);
      final result = await ref
          .read(userServiceProvider(userId).notifier)
          .changeUser(email: _newEmailController.text);
      if (result != null) {
        CustomErrorSnackBar.message(
            message: result, type: CustomErrorSnackBarType.error,);
      } else if (mounted) {
        {
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCloseKeyboardScaffold(
      appBar: AppBar(
        title: const Text('Change Email', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _newEmailController,
                  decoration: const InputDecoration(
                    labelText: 'New Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: LoginService.emailValidatorWithErrorMessage,
                ),
                const SizedBox(height: 50.0),
                SubmitButton(onPressed: _changeEmail, text: 'Change Email'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
