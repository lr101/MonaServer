import 'package:flutter/material.dart';

import 'admin_session_controller.dart';

final class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({required this.controller, super.key});

  final AdminSessionController controller;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

final class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await widget.controller.beginLogin(_username.text, _password.text);
    if (!mounted) return;
    // Password input is cleared as soon as the transport has accepted the
    // challenge; it is never copied into controller state.
    _password.clear();
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 48,
                          color: theme.colorScheme.primary,
                          semanticLabel: 'Admin workspace',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Admin sign in',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your enrolled operator account. Admin sessions are separate from the consumer app.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('admin-username'),
                          controller: _username,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Operator username',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Enter your operator username.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('admin-password'),
                          controller: _password,
                          obscureText: true,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.isEmpty == true
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (state.message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.message!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          key: const ValueKey('admin-sign-in'),
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(_submitting ? 'Starting…' : 'Continue'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'For security, this page never stores admin passwords or consumer credentials.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
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
