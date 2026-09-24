import 'dart:async';

import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_use_cases.dart';

enum EmailLinkRequestViewStatus {
  idle,
  submitting,
  sent,
  invalidEmail,
  unavailable,
  featureUnavailable,
}

final class EmailLinkRequestViewState {
  const EmailLinkRequestViewState._({required this.status, this.identifier});

  const EmailLinkRequestViewState.idle()
    : this._(status: EmailLinkRequestViewStatus.idle);

  const EmailLinkRequestViewState.submitting()
    : this._(status: EmailLinkRequestViewStatus.submitting);

  const EmailLinkRequestViewState.sent(EmailLoginIdentifier identifier)
    : this._(status: EmailLinkRequestViewStatus.sent, identifier: identifier);

  const EmailLinkRequestViewState.invalidEmail()
    : this._(status: EmailLinkRequestViewStatus.invalidEmail);

  const EmailLinkRequestViewState.unavailable()
    : this._(status: EmailLinkRequestViewStatus.unavailable);

  const EmailLinkRequestViewState.featureUnavailable()
    : this._(status: EmailLinkRequestViewStatus.featureUnavailable);

  final EmailLinkRequestViewStatus status;
  final EmailLoginIdentifier? identifier;

  bool get isBusy => status == EmailLinkRequestViewStatus.submitting;

  @override
  String toString() => 'EmailLinkRequestViewState(status: $status)';
}

typedef EmailLinkRequestStateListener = void Function(
  EmailLinkRequestViewState state,
);

/// Coordinates the email entry form and prevents a double submit from
/// creating duplicate delivery requests. The server response remains generic;
/// this controller never asks a port whether an account exists.
final class EmailLinkRequestController {
  EmailLinkRequestController(EmailLinkRequestPort port)
    : _request = RequestEmailLink(port);

  final RequestEmailLink _request;
  final _listeners = <EmailLinkRequestStateListener>{};
  EmailLinkRequestViewState _state = const EmailLinkRequestViewState.idle();
  Future<EmailLinkRequestViewState>? _inFlight;
  int _operation = 0;
  bool _disposed = false;

  EmailLinkRequestViewState get state => _state;

  void addListener(EmailLinkRequestStateListener listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(EmailLinkRequestStateListener listener) {
    _listeners.remove(listener);
  }

  Future<EmailLinkRequestViewState> request(
    String? rawIdentifier, {
    bool asUsername = false,
  }) {
    if (_disposed) return Future.value(_state);
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final operation = ++_operation;
    _emit(const EmailLinkRequestViewState.submitting());
    late Future<EmailLinkRequestViewState> tracked;
    tracked = _runRequest(rawIdentifier, operation, asUsername);
    tracked = tracked.whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    _inFlight = tracked;
    return tracked;
  }

  Future<EmailLinkRequestViewState> _runRequest(
    String? rawIdentifier,
    int operation,
    bool asUsername,
  ) async {
    final result = await _request(rawIdentifier, asUsername: asUsername);
    if (!_isCurrent(operation)) return _state;
    final next = switch (result.status) {
      EmailLinkRequestStatus.accepted => EmailLinkRequestViewState.sent(
        result.identifier!,
      ),
      EmailLinkRequestStatus.invalidEmail =>
        const EmailLinkRequestViewState.invalidEmail(),
      EmailLinkRequestStatus.unavailable =>
        const EmailLinkRequestViewState.unavailable(),
      EmailLinkRequestStatus.featureUnavailable =>
        const EmailLinkRequestViewState.featureUnavailable(),
    };
    _emit(next);
    return next;
  }

  Future<void> cancel() async {
    if (_disposed) return;
    _operation++;
    _inFlight = null;
    _emit(const EmailLinkRequestViewState.idle());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation++;
    _listeners.clear();
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _emit(EmailLinkRequestViewState next) {
    if (_disposed) return;
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}

enum EmailLoginViewStatus {
  idle,
  invalidLink,
  awaitingConfirmation,
  exchanging,
  expiredLink,
  usedLink,
  unavailable,
  awaitingAccountSwitchConfirmation,
  admitting,
  signedIn,
  cleanupRequired,
  staleGeneration,
  admissionFailed,
  accountSwitchDeclined,
}

final class EmailLoginViewState {
  const EmailLoginViewState._({
    required this.status,
    this.canonicalUsername,
    this.exchangeStatus,
    this.admissionStatus,
  });

  const EmailLoginViewState.idle() : this._(status: EmailLoginViewStatus.idle);

  const EmailLoginViewState.invalidLink({
    EmailLinkExchangeStatus? exchangeStatus,
  }) : this._(
         status: EmailLoginViewStatus.invalidLink,
         exchangeStatus: exchangeStatus,
       );

  const EmailLoginViewState.awaitingConfirmation()
    : this._(status: EmailLoginViewStatus.awaitingConfirmation);

  const EmailLoginViewState.exchanging()
    : this._(status: EmailLoginViewStatus.exchanging);

  const EmailLoginViewState.expiredLink()
    : this._(status: EmailLoginViewStatus.expiredLink);

  const EmailLoginViewState.usedLink()
    : this._(status: EmailLoginViewStatus.usedLink);

  const EmailLoginViewState.unavailable({
    EmailLinkExchangeStatus? exchangeStatus,
  }) : this._(
         status: EmailLoginViewStatus.unavailable,
         exchangeStatus: exchangeStatus,
       );

  const EmailLoginViewState.awaitingAccountSwitchConfirmation({
    required String canonicalUsername,
  }) : this._(
         status: EmailLoginViewStatus.awaitingAccountSwitchConfirmation,
         canonicalUsername: canonicalUsername,
       );

  const EmailLoginViewState.admitting()
    : this._(status: EmailLoginViewStatus.admitting);

  const EmailLoginViewState.signedIn({required String canonicalUsername})
    : this._(
        status: EmailLoginViewStatus.signedIn,
        canonicalUsername: canonicalUsername,
      );

  const EmailLoginViewState.cleanupRequired()
    : this._(status: EmailLoginViewStatus.cleanupRequired);

  const EmailLoginViewState.staleGeneration()
    : this._(status: EmailLoginViewStatus.staleGeneration);

  const EmailLoginViewState.admissionFailed()
    : this._(status: EmailLoginViewStatus.admissionFailed);

  const EmailLoginViewState.accountSwitchDeclined()
    : this._(status: EmailLoginViewStatus.accountSwitchDeclined);

  final EmailLoginViewStatus status;
  final String? canonicalUsername;
  final EmailLinkExchangeStatus? exchangeStatus;
  final EmailLoginAdmissionStatus? admissionStatus;

  bool get isBusy =>
      status == EmailLoginViewStatus.exchanging ||
      status == EmailLoginViewStatus.admitting;

  bool get canConfirm => status == EmailLoginViewStatus.awaitingConfirmation;

  bool get needsAccountSwitchConfirmation =>
      status == EmailLoginViewStatus.awaitingAccountSwitchConfirmation;

  @override
  String toString() => 'EmailLoginViewState(status: $status)';
}

typedef EmailLoginStateListener = void Function(EmailLoginViewState state);

/// Owns callback confirmation and admission sequencing for the consumer
/// session. It keeps all token-bearing values private and emits only safe view
/// state. The admission adapter is responsible for the atomic
/// `GlobalDataService.updateData(tokens, canonicalUsername,
/// expectedGeneration:)` transition; sync remains owned by AppSyncLifecycle.
final class EmailLoginController {
  EmailLoginController({
    required EmailLinkExchangePort exchangePort,
    required EmailLoginAdmissionPort admissionPort,
  }) : _exchange = ExchangeEmailLink(exchangePort),
       _admit = AdmitEmailLogin(admissionPort),
       _revokeUseCase = RevokeEmailLoginCredential(admissionPort),
       _admissionPort = admissionPort;

  final ExchangeEmailLink _exchange;
  final AdmitEmailLogin _admit;
  final RevokeEmailLoginCredential _revokeUseCase;
  final EmailLoginAdmissionPort _admissionPort;
  final _listeners = <EmailLoginStateListener>{};

  EmailLoginViewState _state = const EmailLoginViewState.idle();
  EmailLinkToken? _pendingToken;
  EmailLinkExchange? _pendingExchange;
  EmailLoginSessionSnapshot? _pendingSession;
  int? _pendingExpectedGeneration;
  int? _pendingOperation;
  Future<EmailLoginViewState>? _exchangeInFlight;
  Future<EmailLoginViewState>? _admissionInFlight;
  int _operation = 0;
  bool _disposed = false;

  EmailLoginViewState get state => _state;

  void addListener(EmailLoginStateListener listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(EmailLoginStateListener listener) {
    _listeners.remove(listener);
  }

  /// Supplies one-shot launch data after the launch adapter has scrubbed the
  /// browser location. This method deliberately does not exchange the token.
  void setLaunchData(EmailLinkLaunchData launch) {
    if (_disposed) return;
    final previousCredentials = _pendingExchange?.credentials;
    _operation++;
    _exchangeInFlight = null;
    _admissionInFlight = null;
    _clearPending();
    if (previousCredentials != null) {
      unawaited(_revoke(previousCredentials));
    }

    if (launch.hasUsableToken) {
      _pendingToken = launch.token;
      _emit(const EmailLoginViewState.awaitingConfirmation());
    } else {
      // Malformed and scrub-failed launches share one generic user-facing
      // state. The failure detail never reaches diagnostics or the UI.
      _emit(const EmailLoginViewState.invalidLink());
    }
  }

  /// Redeems a captured link after the user explicitly confirms. Repeated
  /// taps share the same future while the POST is in flight.
  Future<EmailLoginViewState> confirmSignIn() {
    if (_disposed) return Future.value(_state);
    final inFlight = _exchangeInFlight;
    if (inFlight != null) return inFlight;
    if (!_state.canConfirm || _pendingToken == null) {
      return Future.value(_state);
    }

    final session = _safeSession();
    if (session == null) {
      _emit(const EmailLoginViewState.unavailable());
      return Future.value(_state);
    }
    if (session.cleanupRequired) {
      _clearPending();
      _emit(const EmailLoginViewState.cleanupRequired());
      return Future.value(_state);
    }

    final token = _pendingToken!;
    final operation = ++_operation;
    _pendingSession = session;
    _pendingExpectedGeneration = session.generation;
    _pendingOperation = operation;
    _emit(const EmailLoginViewState.exchanging());

    late Future<EmailLoginViewState> tracked;
    tracked = _exchangeAndContinue(token, session, operation);
    tracked = tracked.whenComplete(() {
      if (identical(_exchangeInFlight, tracked)) _exchangeInFlight = null;
    });
    _exchangeInFlight = tracked;
    return tracked;
  }

  /// Admits an exchange that identified a different account only after the
  /// user confirms the account switch. The existing session is otherwise left
  /// untouched.
  Future<EmailLoginViewState> confirmAccountSwitch() {
    if (_disposed) return Future.value(_state);
    final inFlight = _admissionInFlight;
    if (inFlight != null) return inFlight;
    if (!_state.needsAccountSwitchConfirmation) {
      return Future.value(_state);
    }
    final exchange = _pendingExchange;
    final session = _pendingSession;
    final expectedGeneration = _pendingExpectedGeneration;
    final operation = _pendingOperation;
    if (exchange == null ||
        session == null ||
        expectedGeneration == null ||
        operation == null) {
      _emit(const EmailLoginViewState.staleGeneration());
      return Future.value(_state);
    }

    late Future<EmailLoginViewState> tracked;
    tracked = _admitPending(exchange, session, expectedGeneration, operation);
    tracked = tracked.whenComplete(() {
      if (identical(_admissionInFlight, tracked)) _admissionInFlight = null;
    });
    _admissionInFlight = tracked;
    return tracked;
  }

  /// Declines a different-account exchange and best-effort revokes the newly
  /// issued refresh credential. The current session remains unchanged.
  Future<EmailLoginViewState> declineAccountSwitch() async {
    if (_disposed || !_state.needsAccountSwitchConfirmation) return _state;
    final exchange = _pendingExchange;
    final operation = ++_operation;
    _clearPending();
    if (exchange != null) {
      await _revoke(exchange.credentials);
    }
    if (!_isCurrent(operation)) return _state;
    _emit(const EmailLoginViewState.accountSwitchDeclined());
    return _state;
  }

  /// Fences pending work when logout or an external account transition starts.
  /// A successful exchange that arrives later is revoked without changing the
  /// current view state.
  Future<void> cancel() async {
    if (_disposed) return;
    _operation++;
    _exchangeInFlight = null;
    _admissionInFlight = null;
    final credentials = _pendingExchange?.credentials;
    _clearPending();
    _emit(const EmailLoginViewState.idle());
    if (credentials != null) await _revoke(credentials);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation++;
    _exchangeInFlight = null;
    _admissionInFlight = null;
    final credentials = _pendingExchange?.credentials;
    _clearPending();
    _listeners.clear();
    if (credentials != null) unawaited(_revoke(credentials));
  }

  Future<EmailLoginViewState> _exchangeAndContinue(
    EmailLinkToken token,
    EmailLoginSessionSnapshot session,
    int operation,
  ) async {
    final result = await _exchange(token);
    if (!_isCurrent(operation)) {
      await _revokeResult(result);
      return _state;
    }

    final current = _safeSession();
    if (current == null ||
        !_generationMatches(session.generation) ||
        current.userId != session.userId) {
      await _revokeResult(result);
      if (!_isCurrent(operation)) return _state;
      _clearPending();
      _emit(const EmailLoginViewState.staleGeneration());
      return _state;
    }
    if (current.cleanupRequired) {
      await _revokeResult(result);
      if (!_isCurrent(operation)) return _state;
      _clearPending();
      _emit(const EmailLoginViewState.cleanupRequired());
      return _state;
    }

    _pendingToken = null;
    switch (result.status) {
      case EmailLinkExchangeStatus.success:
        final exchange = result.exchange;
        if (exchange == null) {
          _clearPending();
          _emit(const EmailLoginViewState.unavailable());
          return _state;
        }
        _pendingExchange = exchange;
        if (session.userId != null &&
            session.userId != exchange.credentials.userId) {
          _emit(
            EmailLoginViewState.awaitingAccountSwitchConfirmation(
              canonicalUsername: exchange.canonicalUsername,
            ),
          );
          return _state;
        }
        return _admitPending(exchange, session, session.generation, operation);
      case EmailLinkExchangeStatus.invalid:
        _clearPending();
        _emit(
          const EmailLoginViewState.invalidLink(
            exchangeStatus: EmailLinkExchangeStatus.invalid,
          ),
        );
        return _state;
      case EmailLinkExchangeStatus.expired:
        _clearPending();
        _emit(const EmailLoginViewState.expiredLink());
        return _state;
      case EmailLinkExchangeStatus.used:
      case EmailLinkExchangeStatus.reused:
        _clearPending();
        _emit(const EmailLoginViewState.usedLink());
        return _state;
      case EmailLinkExchangeStatus.unavailable:
        _clearPending();
        _emit(
          const EmailLoginViewState.unavailable(
            exchangeStatus: EmailLinkExchangeStatus.unavailable,
          ),
        );
        return _state;
    }
  }

  Future<EmailLoginViewState> _admitPending(
    EmailLinkExchange exchange,
    EmailLoginSessionSnapshot session,
    int expectedGeneration,
    int operation,
  ) async {
    if (!_isCurrent(operation)) {
      await _revoke(exchange.credentials);
      return _state;
    }
    final current = _safeSession();
    if (current == null ||
        !_generationMatches(expectedGeneration) ||
        current.userId != session.userId) {
      await _revoke(exchange.credentials);
      if (!_isCurrent(operation)) return _state;
      _clearPending();
      _emit(const EmailLoginViewState.staleGeneration());
      return _state;
    }
    if (current.cleanupRequired) {
      await _revoke(exchange.credentials);
      if (!_isCurrent(operation)) return _state;
      _clearPending();
      _emit(const EmailLoginViewState.cleanupRequired());
      return _state;
    }

    _emit(const EmailLoginViewState.admitting());
    EmailLoginAdmissionResult result;
    try {
      result = await _admit(exchange, expectedGeneration: expectedGeneration);
    } catch (_) {
      result = const EmailLoginAdmissionResult.failed();
    }

    if (!_isCurrent(operation)) {
      // A successful adapter call owns the credential now. A failed or stale
      // call still needs best-effort revocation because the link is consumed.
      if (!result.isAccepted) {
        await _revoke(exchange.credentials);
      }
      return _state;
    }

    _clearPending();
    if (result.isAccepted) {
      _emit(
        EmailLoginViewState.signedIn(
          canonicalUsername: exchange.canonicalUsername,
        ),
      );
      return _state;
    }
    await _revoke(exchange.credentials);
    if (!_isCurrent(operation)) return _state;
    final next = switch (result.status) {
      EmailLoginAdmissionStatus.staleGeneration =>
        const EmailLoginViewState.staleGeneration(),
      EmailLoginAdmissionStatus.cleanupRequired =>
        const EmailLoginViewState.cleanupRequired(),
      EmailLoginAdmissionStatus.failed =>
        const EmailLoginViewState.admissionFailed(),
      EmailLoginAdmissionStatus.accepted =>
        const EmailLoginViewState.admissionFailed(),
    };
    _emit(next);
    return _state;
  }

  Future<void> _revokeResult(EmailLinkExchangeResult result) async {
    final exchange = result.exchange;
    if (result.isSuccess && exchange != null) {
      await _revoke(exchange.credentials);
    }
  }

  Future<void> _revoke(EmailLoginCredentials credentials) =>
      _revokeUseCase.call(credentials);

  bool _generationMatches(int expectedGeneration) {
    try {
      return _admissionPort.isGenerationCurrent(expectedGeneration) &&
          _admissionPort.session.generation == expectedGeneration;
    } catch (_) {
      return false;
    }
  }

  EmailLoginSessionSnapshot? _safeSession() {
    try {
      return _admissionPort.session;
    } catch (_) {
      return null;
    }
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _clearPending() {
    _pendingToken = null;
    _pendingExchange = null;
    _pendingSession = null;
    _pendingExpectedGeneration = null;
    _pendingOperation = null;
  }

  void _emit(EmailLoginViewState next) {
    if (_disposed) return;
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}

enum EmailRecoveryViewStatus {
  idle,
  invalidToken,
  submitting,
  completed,
  invalidPassword,
  expiredToken,
  usedToken,
  unavailable,
}

final class EmailRecoveryViewState {
  const EmailRecoveryViewState._(this.status);

  const EmailRecoveryViewState.idle() : this._(EmailRecoveryViewStatus.idle);

  const EmailRecoveryViewState.invalidToken()
    : this._(EmailRecoveryViewStatus.invalidToken);

  const EmailRecoveryViewState.submitting()
    : this._(EmailRecoveryViewStatus.submitting);

  const EmailRecoveryViewState.completed()
    : this._(EmailRecoveryViewStatus.completed);

  const EmailRecoveryViewState.invalidPassword()
    : this._(EmailRecoveryViewStatus.invalidPassword);

  const EmailRecoveryViewState.expiredToken()
    : this._(EmailRecoveryViewStatus.expiredToken);

  const EmailRecoveryViewState.usedToken()
    : this._(EmailRecoveryViewStatus.usedToken);

  const EmailRecoveryViewState.unavailable()
    : this._(EmailRecoveryViewStatus.unavailable);

  final EmailRecoveryViewStatus status;

  bool get isBusy => status == EmailRecoveryViewStatus.submitting;

  @override
  String toString() => 'EmailRecoveryViewState(status: $status)';
}

typedef EmailRecoveryStateListener = void Function(
  EmailRecoveryViewState state,
);

/// Handles the restricted recovery form. A recovery token is accepted only in
/// memory and is consumed by an explicit password submission.
final class EmailRecoveryController {
  EmailRecoveryController(EmailRecoveryPort port)
    : _complete = CompleteEmailRecovery(port);

  final CompleteEmailRecovery _complete;
  final _listeners = <EmailRecoveryStateListener>{};
  EmailRecoveryViewState _state = const EmailRecoveryViewState.idle();
  RecoveryToken? _token;
  Future<EmailRecoveryViewState>? _inFlight;
  int _operation = 0;
  bool _disposed = false;

  EmailRecoveryViewState get state => _state;

  void addListener(EmailRecoveryStateListener listener) {
    if (!_disposed) _listeners.add(listener);
  }

  void removeListener(EmailRecoveryStateListener listener) {
    _listeners.remove(listener);
  }

  /// Setting a token only prepares the form; it never calls the recovery port.
  void setToken(String? rawToken) {
    if (_disposed) return;
    _operation++;
    _inFlight = null;
    _token = RecoveryToken.tryParse(rawToken);
    _emit(
      _token == null
          ? const EmailRecoveryViewState.invalidToken()
          : const EmailRecoveryViewState.idle(),
    );
  }

  Future<EmailRecoveryViewState> submit(String? rawPassword) {
    if (_disposed) return Future.value(_state);
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final token = _token;
    if (token == null) {
      _emit(const EmailRecoveryViewState.invalidToken());
      return Future.value(_state);
    }

    final operation = ++_operation;
    _emit(const EmailRecoveryViewState.submitting());
    late Future<EmailRecoveryViewState> tracked;
    tracked = _submit(token, rawPassword, operation);
    tracked = tracked.whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    _inFlight = tracked;
    return tracked;
  }

  Future<EmailRecoveryViewState> _submit(
    RecoveryToken token,
    String? rawPassword,
    int operation,
  ) async {
    final result = await _complete(token, rawPassword);
    if (!_isCurrent(operation)) return _state;
    if (result.status != RecoveryCompletionStatus.invalidPassword) {
      _token = null;
    }
    final next = switch (result.status) {
      RecoveryCompletionStatus.completed =>
        const EmailRecoveryViewState.completed(),
      RecoveryCompletionStatus.invalidPassword =>
        const EmailRecoveryViewState.invalidPassword(),
      RecoveryCompletionStatus.invalidToken =>
        const EmailRecoveryViewState.invalidToken(),
      RecoveryCompletionStatus.expiredToken =>
        const EmailRecoveryViewState.expiredToken(),
      RecoveryCompletionStatus.usedToken =>
        const EmailRecoveryViewState.usedToken(),
      RecoveryCompletionStatus.unavailable =>
        const EmailRecoveryViewState.unavailable(),
    };
    _emit(next);
    return next;
  }

  Future<void> cancel() async {
    if (_disposed) return;
    _operation++;
    _inFlight = null;
    _token = null;
    _emit(const EmailRecoveryViewState.idle());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operation++;
    _inFlight = null;
    _token = null;
    _listeners.clear();
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _emit(EmailRecoveryViewState next) {
    if (_disposed) return;
    _state = next;
    for (final listener in List.of(_listeners)) {
      listener(next);
    }
  }
}
