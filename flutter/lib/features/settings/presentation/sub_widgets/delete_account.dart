import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DeleteAccount extends ConsumerStatefulWidget {
  const DeleteAccount({super.key});

  @override
  ConsumerState<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<DeleteAccount> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      CustomErrorSnackBar.message(message: "Sending code to your email");
      final result = await ref.watch(authServiceProvider.notifier).getDeleteCode();
      if (result != null) {
        CustomErrorSnackBar.message(
            message: "Error while sending code: $result",);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomCloseKeyboardScaffold(
        appBar: AppBar(
          title: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text("Are you sure you want to delete your account?", style: TextStyle(fontStyle: FontStyle.italic)),
              const Text("This action cannot be undone, all data will be lost!!",style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16,),
              const Text("Type the Code from your email here:"),
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextFormField(
                  controller: _controller,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: '6 Digit Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v != null && v.length == 6 ? null: "Code must have 6 digits",
                ),
              ),
              const SizedBox(height: 50,),
              SubmitButton(onPressed: _submitDelete, text: "Delete Account"),
            ],
          ),
        ),),);
  }

  Future<void> _submitDelete() async {
    if (_formKey.currentState!.validate()) {
      final result = await ref.watch(authServiceProvider.notifier)
          .deleteAccount(int.parse(_controller.text));
      if (result != null) {
        CustomErrorSnackBar.message(message: result);
      } else if (mounted) {
        context.goNamed("login");
      }
    }
  }
}
