import 'package:flutter/material.dart';

import '../domain/admin_session_controller.dart';

final class AdminMfaScreen extends StatefulWidget {
  const AdminMfaScreen({required this.controller, super.key});

  final AdminSessionController controller;

  @override
  State<AdminMfaScreen> createState() => _AdminMfaScreenState();
}

final class _AdminMfaScreenState extends State<AdminMfaScreen> {
  final _code = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    await widget.controller.completeMfa(_code.text);
    if (!mounted) return;
    _code.clear();
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                        semanticLabel: 'Multi-factor verification',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Multi-factor verification',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the current code from your authenticator app. This challenge is single use.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        key: const ValueKey('admin-mfa-code'),
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 12,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          prefixIcon: Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      if (state.message != null) ...[
                        const SizedBox(height: 12),
                        Text(state.message!),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        key: const ValueKey('admin-verify-mfa'),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_open_outlined),
                        label: Text(
                          _submitting
                              ? 'Verifying…'
                              : 'Verify and open workspace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : widget.controller.logout,
                        child: const Text('Cancel and sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
