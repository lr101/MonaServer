import 'package:buff_lisa/core/session/session_status.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/email_login/data/email_login_providers.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart' show LoginData, SignupData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:string_validator/string_validator.dart';

enum _AuthMode { login, signup }

class Auth extends ConsumerStatefulWidget {
  const Auth({super.key});

  @override
  ConsumerState<Auth> createState() => _AuthState();
}

class _AuthState extends ConsumerState<Auth> {
  final _formKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _emailConfirmation = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _showPassword = false;
  bool _useIdentifierAsUsername = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _busy = false;
  bool _linkSent = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _username.dispose();
    _password.dispose();
    _email.dispose();
    _emailConfirmation.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    if (_busy) return;
    final identifier = _identifier.text.trim();
    final password = _password.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email or username and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(loginServiceProvider)
        .authUser(LoginData(name: identifier, password: password));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) context.goNamed('home');
  }

  Future<void> _requestEmailLink() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await RequestEmailLink(
      ref.read(emailLinkRequestPortProvider),
    )(_identifier.text, asUsername: _useIdentifierAsUsername);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _linkSent = result.status == EmailLinkRequestStatus.accepted;
      _error = switch (result.status) {
        EmailLinkRequestStatus.accepted => null,
        EmailLinkRequestStatus.invalidEmail =>
          'Enter a valid email address or username.',
        EmailLinkRequestStatus.unavailable =>
          'We could not send a sign-in link. Please try again.',
      };
    });
  }

  Future<void> _recoverPassword() async {
    final username = _identifier.text.trim();
    if (username.isEmpty) {
      setState(
        () => _error = 'Enter your username first to reset your password.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(loginServiceProvider)
        .recoverPassword(username);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error =
          error ??
          'If the account can be recovered, check its email for a reset link.';
    });
  }

  Future<void> _signup() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      setState(
        () =>
            _error = 'Please accept the terms and privacy policy to continue.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(loginServiceProvider)
        .signupUser(
          SignupData.fromSignupForm(
            name: _username.text.trim(),
            password: _password.text,
            additionalSignupData: {'email': _email.text.trim()},
          ),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) context.goNamed('home');
  }

  void _switchMode(_AuthMode mode) => setState(() {
    _mode = mode;
    _error = null;
    _linkSent = false;
  });

  void _openLegal(String path, String title) {
    final host = ref.read(globalDataServiceProvider).host;
    context.pushNamed(
      'web',
      queryParameters: {'url': '$host/public/$path', 'title': title},
    );
  }

  @override
  Widget build(BuildContext context) {
    final global = ref.watch(globalDataServiceProvider);
    final theme = Theme.of(context);
    final signup = _mode == _AuthMode.signup;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: signup
                    ? _signupForm(theme)
                    : _loginForm(theme, global.sessionStatus),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) => Column(
    key: ValueKey(title),
    children: [
      Image.asset(
        'assets/icon/logo-rounded-corners.png',
        width: 82,
        height: 82,
      ),
      const SizedBox(height: 18),
      Text(
        title,
        style: theme.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
    ],
  );

  Widget _loginForm(ThemeData theme, SessionStatus status) => Form(
    key: _loginFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(
          theme,
          title: 'Welcome back',
          subtitle: status == SessionStatus.expired
              ? 'Your session expired. Sign in again to continue.'
              : 'Sign in to continue to Buff Lisa.',
        ),
        TextField(
          key: const Key('auth-identifier'),
          controller: _identifier,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: _showPassword
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) => _showPassword ? null : _requestEmailLink(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _showPassword ? 'Username' : 'Email or username',
            helperText: _showPassword
                ? 'Password sign-in uses your username.'
                : null,
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        if (_showPassword) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('auth-password'),
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loginWithPassword(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
        if (!_showPassword) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('auth-login-email'),
            onPressed: _busy || _linkSent ? null : _requestEmailLink,
            icon: const Icon(Icons.mail_outline),
            label: Text(
              _linkSent ? 'Sign-in link sent' : 'Continue with email',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _useIdentifierAsUsername,
            onChanged: _busy
                ? null
                : (value) =>
                      setState(() => _useIdentifierAsUsername = value ?? false),
            title: const Text('Use as username'),
            subtitle: const Text(
              'Choose this if your username looks like an email address.',
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('auth-login-password'),
            onPressed: _busy ? null : _loginWithPassword,
            child: _busy
                ? const _BusyLabel()
                : const Text('Sign in with password'),
          ),
        ],
        if (_linkSent)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'If an account is eligible, a sign-in link is on its way. Check your inbox.',
            ),
          ),
        if (_error != null) _errorText(theme),
        if (_showPassword)
          TextButton(
            onPressed: _busy ? null : _recoverPassword,
            child: const Text('Forgot password?'),
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _showPassword = !_showPassword),
          child: Text(
            _showPassword ? 'Use email link instead' : 'Sign in with password',
          ),
        ),
        const Divider(height: 28),
        OutlinedButton(
          key: const Key('auth-open-signup'),
          onPressed: _busy ? null : () => _switchMode(_AuthMode.signup),
          child: const Text('Create an account'),
        ),
        const SizedBox(height: 20),
        _legalLinks(),
      ],
    ),
  );

  Widget _signupForm(ThemeData theme) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(
          theme,
          title: 'Create your account',
          subtitle: 'A few details and you’re ready to go.',
        ),
        TextFormField(
          key: const Key('signup-username'),
          controller: _username,
          enabled: !_busy,
          autofillHints: const [AutofillHints.newUsername],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) => LoginService.userValidator(value) == null
              ? null
              : 'Use 2–29 letters, numbers, or these symbols: !@#\$%^&*',
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('signup-email'),
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email address',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          validator: (value) => isEmail(value?.trim() ?? '')
              ? null
              : 'Enter a valid email address.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('signup-email-confirmation'),
          controller: _emailConfirmation,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Confirm email address',
            prefixIcon: Icon(Icons.mark_email_read_outlined),
          ),
          validator: (value) =>
              value?.trim().toLowerCase() == _email.text.trim().toLowerCase() &&
                  value!.isNotEmpty
              ? null
              : 'Email addresses do not match.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('signup-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'At least 8 characters. You can change it later.',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
          validator: (value) {
            final error = LoginService.passwordValidator(value);
            if (error != null) return error;
            if (value!.length < 8) return 'Use at least 8 characters.';
            return null;
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const Key('signup-terms-consent'),
          contentPadding: EdgeInsets.zero,
          value: _acceptedTerms,
          onChanged: _busy
              ? null
              : (value) => setState(() => _acceptedTerms = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Wrap(
            children: [
              const Text('I agree to the '),
              _legalButton('Terms of Service', 'agb'),
            ],
          ),
        ),
        CheckboxListTile(
          key: const Key('signup-privacy-consent'),
          contentPadding: EdgeInsets.zero,
          value: _acceptedPrivacy,
          onChanged: _busy
              ? null
              : (value) => setState(() => _acceptedPrivacy = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Wrap(
            children: [
              const Text('I agree to the '),
              _legalButton('Privacy Policy', 'privacy-policy'),
            ],
          ),
        ),
        if (_error != null) _errorText(theme),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('signup-submit'),
          onPressed: _busy ? null : _signup,
          child: _busy ? const _BusyLabel() : const Text('Create account'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _switchMode(_AuthMode.login),
          child: const Text('Already have an account? Sign in'),
        ),
      ],
    ),
  );

  Widget _errorText(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      _error!,
      key: const Key('auth-error'),
      style: TextStyle(color: theme.colorScheme.error),
      textAlign: TextAlign.center,
    ),
  );

  Widget _legalButton(String label, String path) => TextButton(
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () => _openLegal(path == 'agb' ? 'agb' : path, label),
    child: Text(label),
  );

  Widget _legalLinks() => Wrap(
    alignment: WrapAlignment.center,
    children: [
      const Text('By continuing, you agree to our '),
      _legalButton('Terms of Service', 'agb'),
      const Text(' and '),
      _legalButton('Privacy Policy', 'privacy-policy'),
    ],
  );
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel();
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
