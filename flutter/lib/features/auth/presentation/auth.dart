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

enum _AuthMode { login, signup, verificationPending }

class Auth extends ConsumerStatefulWidget {
  const Auth({super.key});

  @override
  ConsumerState<Auth> createState() => _AuthState();
}

class _AuthState extends ConsumerState<Auth> {
  final _formKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();
  final _verificationFormKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _showPassword = false;
  bool _showSignupPassword = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _busy = false;
  String? _error;
  String? _verificationNotice;

  @override
  void dispose() {
    _identifier.dispose();
    _username.dispose();
    _password.dispose();
    _email.dispose();
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
    if (error == 'email is not confirmed') {
      setState(() {
        _mode = _AuthMode.verificationPending;
        _username.text = identifier;
        _email.clear();
        _verificationNotice = 'This account still needs email confirmation. Enter the address you used, or correct it, and we’ll send a fresh link.';
        _busy = false;
        _error = null;
      });
      return;
    }
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
    )(_identifier.text);
    if (!mounted) return;
    if (result.status == EmailLinkRequestStatus.accepted) {
      setState(() => _busy = false);
      context.pushNamed('emailLoginCode', extra: result.identifier);
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (result.status) {
        EmailLinkRequestStatus.accepted => null,
        EmailLinkRequestStatus.invalidEmail =>
          'Enter a valid email address or username.',
        EmailLinkRequestStatus.unavailable =>
          'We could not send a sign-in code. Please try again.',
        EmailLinkRequestStatus.featureUnavailable => 'Email sign-in is not enabled on this server yet. Try username and password instead.',
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
    final error = await _sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) {
        _mode = _AuthMode.verificationPending;
        _verificationNotice =
            'We sent a verification link to ${_email.text.trim()}.';
      }
    });
  }

  Future<String?> _sendVerificationEmail() => ref
      .read(loginServiceProvider)
      .signupUser(
        SignupData.fromSignupForm(
          name: _username.text.trim(),
          password: _password.text,
          additionalSignupData: {'email': _email.text.trim()},
        ),
      );

  Future<void> _resendVerification() async {
    if (_busy || !_verificationFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _sendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error == 'username already exists'
          ? 'We couldn’t confirm those signup details. Sign in or check your username and password.'
          : error;
      if (error == null) {
        _verificationNotice =
            'We sent a fresh verification link to ${_email.text.trim()}.';
      }
    });
  }

  void _openPendingSignIn() => setState(() {
    _mode = _AuthMode.login;
    _showPassword = true;
    _identifier.text = _username.text;
    _error = null;
  });

  void _switchMode(_AuthMode mode) => setState(() {
    _mode = mode;
    _error = null;
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
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    reverseDuration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: switch (_mode) {
                      _AuthMode.login => _loginForm(
                        theme,
                        global.sessionStatus,
                      ),
                      _AuthMode.signup => _signupForm(theme),
                      _AuthMode.verificationPending => _verificationPendingForm(
                        theme,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(ThemeData theme, {required String title, String? subtitle}) =>
      Column(
        key: ValueKey(title),
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset('assets/icon/logo-rounded-corners.png'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 28),
        ],
      );

  Widget _loginForm(ThemeData theme, SessionStatus status) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: _loginContent(theme, status),
  );

  Widget _loginContent(ThemeData theme, SessionStatus status) => Form(
    key: _loginFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(
          theme,
          title: 'Sign in',
          subtitle: status == SessionStatus.expired
              ? 'Your session expired. Sign in again to continue.'
              : null,
        ),
        TextField(
          key: const Key('auth-identifier'),
          controller: _identifier,
          enabled: !_busy,
          autofillHints: const [AutofillHints.username],
          keyboardType: _showPassword
              ? TextInputType.text
              : TextInputType.emailAddress,
          textInputAction: _showPassword
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) => _showPassword ? null : _requestEmailLink(),
          decoration: InputDecoration(
            labelText: _showPassword ? 'Username' : 'Email or username',
            helperText: _showPassword ? 'Use your account username.' : null,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            key: ValueKey(_showPassword),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showPassword) ...[
                TextField(
                  key: const Key('auth-password'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loginWithPassword(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: Key(
                    _showPassword ? 'auth-login-password' : 'auth-login-email',
                  ),
                  onPressed: _busy
                      ? null
                      : _showPassword
                      ? _loginWithPassword
                      : _requestEmailLink,
                  child: _busy
                      ? const _BusyLabel()
                      : Text(_showPassword ? 'Sign in' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _error == null ? const SizedBox.shrink() : _errorText(theme),
        ),
        if (_showPassword)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _recoverPassword,
              child: const Text('Forgot password?'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('auth-toggle-signin-method'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _showPassword = !_showPassword;
                    _error = null;
                  }),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              minimumSize: const Size(0, 48),
              visualDensity: VisualDensity.standard,
            ),
            child: Text(
              _showPassword
                  ? 'Use email code instead'
                  : 'Sign in with password',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Need an account?'),
            TextButton(
              key: const Key('auth-open-signup'),
              onPressed: _busy ? null : () => _switchMode(_AuthMode.signup),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
                visualDensity: VisualDensity.standard,
              ),
              child: const Text('Create account'),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          subtitle: 'Create an account, then verify your email to sign in.',
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
              : 'Use 2–29 letters, numbers, or !#\$%^&* (no @).',
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
          key: const Key('signup-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: !_showSignupPassword,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'At least 8 characters. You can change it later.',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _showSignupPassword = !_showSignupPassword),
              icon: Icon(
                _showSignupPassword ? Icons.visibility_off : Icons.visibility,
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
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _error == null ? const SizedBox.shrink() : _errorText(theme),
        ),
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

  Widget _verificationPendingForm(ThemeData theme) => Form(
    key: _verificationFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(
          theme,
          title: 'Check your email',
          subtitle: 'Confirm your address before signing in.',
        ),
        Text(
          _verificationNotice ?? 'Enter the email address for this account. You can correct it here and we’ll send a fresh verification link.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const Key('pending-verification-email'),
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
        const SizedBox(height: 8),
        Text(
          'The link expires after 24 hours. You can request another link if needed.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _error == null ? const SizedBox.shrink() : _errorText(theme),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('pending-verification-submit'),
          onPressed: _busy ? null : _resendVerification,
          child: _busy
              ? const _BusyLabel()
              : const Text('Send verification email'),
        ),
        TextButton(
          onPressed: _busy ? null : _openPendingSignIn,
          child: const Text('Already verified? Sign in'),
        ),
      ],
    ),
  );

  Widget _errorText(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      key: const Key('auth-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
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
