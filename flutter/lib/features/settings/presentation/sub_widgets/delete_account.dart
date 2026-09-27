import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings_widgets.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _requestingCode = true;
  String _codeMessage = 'Sending a confirmation code to your email…';
  bool _codeRequestFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestDeleteCode());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestDeleteCode() async {
    if (!mounted) return;
    setState(() {
      _requestingCode = true;
      _codeMessage = 'Sending a confirmation code to your email…';
      _codeRequestFailed = false;
    });
    String? result;
    try {
      result = await ref.read(authServiceProvider.notifier).getDeleteCode();
    } catch (_) {
      result = 'request failed';
    }
    if (!mounted) return;
    setState(() {
      _requestingCode = false;
      _codeRequestFailed = result != null;
      _codeMessage = result == null
          ? 'A six-digit confirmation code was sent to your email.'
          : 'We could not send the code. Please check your connection and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsPageScaffold(
      title: 'Delete account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This permanently deletes your account.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account and its data cannot be restored after deletion.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_requestingCode)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _codeRequestFailed
                          ? Icons.error_outline
                          : Icons.mark_email_read_outlined,
                      color: _codeRequestFailed ? colors.error : colors.primary,
                    ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_codeMessage)),
                ],
              ),
            ),
            if (_codeRequestFailed) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: _requestDeleteCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SettingsPanel(
              child: TextFormField(
                controller: _controller,
                maxLength: 6,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Confirmation code',
                  hintText: '6 digits',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value != null && RegExp(r'^\d{6}$').hasMatch(value)
                    ? null
                    : 'Enter the six-digit code',
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionButton(
              label: 'Delete account',
              icon: Icons.delete_forever_outlined,
              destructive: true,
              enabled: !_requestingCode && !_codeRequestFailed,
              onPressed: _submitDelete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDelete() async {
    if (_formKey.currentState!.validate()) {
      try {
        final result = await ref
            .read(authServiceProvider.notifier)
            .deleteAccount(int.parse(_controller.text));
        if (!mounted) return;
        if (result != null) {
          CustomErrorSnackBar.message(message: result);
        } else {
          context.goNamed('login');
        }
      } catch (_) {
        if (!mounted) return;
        if (ref.read(globalDataServiceProvider.notifier).cleanupRequired) {
          context.goNamed('logout');
        } else {
          CustomErrorSnackBar.message(
            message: 'Account deletion failed. Please retry.',
            type: CustomErrorSnackBarType.error,
          );
        }
      }
    }
  }
}
