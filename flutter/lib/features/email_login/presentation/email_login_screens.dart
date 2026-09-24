import 'dart:async';

import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/presentation/email_login_controller.dart';
import 'package:flutter/material.dart';

typedef EmailLoginNavigation = void Function();

class EmailLinkRequestScreen extends StatefulWidget {
  const EmailLinkRequestScreen({
    required this.requestPort,
    this.onBack,
    super.key,
  });

  final EmailLinkRequestPort requestPort;
  final EmailLoginNavigation? onBack;

  @override
  State<EmailLinkRequestScreen> createState() => _EmailLinkRequestScreenState();
}

class _EmailLinkRequestScreenState extends State<EmailLinkRequestScreen> {
  late final EmailLinkRequestController _controller;
  late final TextEditingController _identifier;
  bool _asUsername = false;

  @override
  void initState() {
    super.initState();
    _controller = EmailLinkRequestController(widget.requestPort)
      ..addListener(_onStateChanged);
    _identifier = TextEditingController();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onStateChanged)
      ..dispose();
    _identifier.dispose();
    super.dispose();
  }

  void _onStateChanged(EmailLinkRequestViewState state) {
    if (mounted) setState(() {});
  }

  void _submit() {
    if (!_controller.state.isBusy) {
      unawaited(_controller.request(_identifier.text, asUsername: _asUsername));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Sign in with an email link'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: state.status == EmailLinkRequestViewStatus.sent
                  ? _sentBody(state)
                  : _entryBody(state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryBody(EmailLinkRequestViewState state) {
    final error = switch (state.status) {
      EmailLinkRequestViewStatus.invalidEmail =>
        'Enter a valid email address or username.',
      EmailLinkRequestViewStatus.unavailable =>
        'The sign-in email could not be sent. Please try again.',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in without a password',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your email address or username. If your account is eligible, we will send a one-time sign-in link to its verified email address.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('email-login-email'),
          controller: _identifier,
          enabled: !state.isBusy,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Email address or username',
          ),
        ),
        SwitchListTile(
          key: const Key('email-login-username-mode'),
          title: const Text('Use as username'),
          subtitle: const Text(
            'Select this if your username looks like an email address or uses other characters.',
          ),
          value: _asUsername,
          onChanged: state.isBusy
              ? null
              : (value) => setState(() => _asUsername = value),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('email-login-request'),
          onPressed: state.isBusy ? null : _submit,
          child: const Text('Send sign-in link'),
        ),
      ],
    );
  }

  Widget _sentBody(EmailLinkRequestViewState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.mark_email_read_outlined, size: 56),
      const SizedBox(height: 16),
      Text(
        'Check your email',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
        'If an account is eligible, a sign-in link is on its way.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        key: const Key('email-login-resend'),
        onPressed: state.isBusy ? null : _submit,
        child: const Text('Resend link'),
      ),
      TextButton(
        key: const Key('email-login-use-another'),
        onPressed: state.isBusy
            ? null
            : () {
                _identifier.clear();
                unawaited(_controller.cancel());
              },
        child: const Text('Use another email address'),
      ),
    ],
  );
}

/// Does not exchange a captured token until the user explicitly confirms.
class EmailLoginCallbackScreen extends StatefulWidget {
  const EmailLoginCallbackScreen({
    required this.launch,
    required this.exchangePort,
    required this.admissionPort,
    this.onRequestNewLink,
    this.onSignedIn,
    this.onBack,
    super.key,
  });

  final EmailLinkLaunchData? launch;
  final EmailLinkExchangePort exchangePort;
  final EmailLoginAdmissionPort admissionPort;
  final EmailLoginNavigation? onRequestNewLink;
  final EmailLoginNavigation? onSignedIn;
  final EmailLoginNavigation? onBack;

  @override
  State<EmailLoginCallbackScreen> createState() =>
      _EmailLoginCallbackScreenState();
}

class _EmailLoginCallbackScreenState extends State<EmailLoginCallbackScreen> {
  late final EmailLoginController _controller;
  var _sentSignedInNavigation = false;

  @override
  void initState() {
    super.initState();
    _controller =
        EmailLoginController(
            exchangePort: widget.exchangePort,
            admissionPort: widget.admissionPort,
          )
          ..addListener(_onStateChanged)
          ..setLaunchData(
            widget.launch ?? const EmailLinkLaunchData.malformed(),
          );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onStateChanged)
      ..dispose();
    super.dispose();
  }

  void _onStateChanged(EmailLoginViewState state) {
    if (!mounted) return;
    setState(() {});
    if (state.status == EmailLoginViewStatus.signedIn &&
        !_sentSignedInNavigation) {
      _sentSignedInNavigation = true;
      widget.onSignedIn?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: widget.onBack),
      title: const Text('Email sign in'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _body(_controller.state),
          ),
        ),
      ),
    ),
  );

  Widget _body(EmailLoginViewState state) => switch (state.status) {
    EmailLoginViewStatus.awaitingConfirmation => _confirmationBody(),
    EmailLoginViewStatus.exchanging || EmailLoginViewStatus.admitting =>
      const Center(child: CircularProgressIndicator()),
    EmailLoginViewStatus.awaitingAccountSwitchConfirmation => _switchBody(
      state.canonicalUsername!,
    ),
    EmailLoginViewStatus.signedIn => _message(
      'Signed in successfully.',
      'Your session is ready.',
    ),
    EmailLoginViewStatus.expiredLink => _problem(
      'This link has expired.',
      'Request a new sign-in link to continue.',
    ),
    EmailLoginViewStatus.usedLink => _problem(
      'This link has already been used.',
      'Request a new sign-in link to continue.',
    ),
    EmailLoginViewStatus.unavailable => _problem(
      'The sign-in service is unavailable.',
      'Please request a fresh link and try again.',
    ),
    EmailLoginViewStatus.invalidLink || EmailLoginViewStatus.idle => _problem(
      'This link is invalid or unavailable.',
      'Request a fresh link and try again.',
    ),
    EmailLoginViewStatus.cleanupRequired => _message(
      'Finish account cleanup first.',
      'Your existing session still needs to finish signing out.',
    ),
    EmailLoginViewStatus.staleGeneration => _message(
      'This sign-in attempt is no longer current.',
      'Request a fresh link and try again.',
    ),
    EmailLoginViewStatus.admissionFailed => _problem(
      'We could not finish signing you in.',
      'Request a fresh link and try again.',
    ),
    EmailLoginViewStatus.accountSwitchDeclined => _message(
      'Your current account is unchanged.',
      'The new sign-in link was not accepted.',
    ),
  };

  Widget _confirmationBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Continue with email sign in?',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      const Text(
        'Only continue if you requested this link. It may sign you into a different account.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        key: const Key('email-login-confirm'),
        onPressed: () => unawaited(_controller.confirmSignIn()),
        child: const Text('Sign in'),
      ),
    ],
  );

  Widget _switchBody(String username) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sign in as $username?',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      const Text(
        'Continuing will sign out the current account and clear its local data before switching.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        key: const Key('email-login-confirm-switch'),
        onPressed: () => unawaited(_controller.confirmAccountSwitch()),
        child: const Text('Switch account'),
      ),
      TextButton(
        key: const Key('email-login-decline-switch'),
        onPressed: () => unawaited(_controller.declineAccountSwitch()),
        child: const Text('Keep current account'),
      ),
    ],
  );

  Widget _problem(String title, String message) => _message(
    title,
    message,
    action: FilledButton(
      key: const Key('email-login-request-new'),
      onPressed: widget.onRequestNewLink,
      child: const Text('Request a new link'),
    ),
  );

  Widget _message(String title, String message, {Widget? action}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: 24), action],
    ],
  );
}
