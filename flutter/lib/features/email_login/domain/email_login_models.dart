/// Canonical, non-secret email value used by the public login contract.
final class EmailAddress {
  const EmailAddress._(this.value);

  /// Trims surrounding whitespace and applies case folding. Provider-specific
  /// dot and plus rewriting is deliberately not applied.
  static EmailAddress? tryParse(String? input) {
    if (input == null) return null;
    final value = input.trim().toLowerCase();
    if (value.isEmpty || value.length > 254) return null;

    final at = value.indexOf('@');
    if (at <= 0 || at != value.lastIndexOf('@') || at == value.length - 1) {
      return null;
    }

    final local = value.substring(0, at);
    final domain = value.substring(at + 1);
    if (local.length > 64 ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        RegExp(r'\s').hasMatch(value)) {
      return null;
    }
    if (!RegExp(r"^[A-Za-z0-9.!#\$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
      return null;
    }

    final labels = domain.split('.');
    final labelPattern = RegExp(
      r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
    );
    if (labels.length < 2 ||
        labels.any((label) => !labelPattern.hasMatch(label))) {
      return null;
    }
    return EmailAddress._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Public sign-in identifier. A valid email is canonicalized; a username
/// preserves its case because the existing password flow uses exact names.
enum EmailLoginIdentifierKind { email, username }

final class EmailLoginIdentifier {
  const EmailLoginIdentifier._(this.value, this.kind);

  static EmailLoginIdentifier? tryParse(
    String? input, {
    bool asUsername = false,
  }) {
    final trimmed = input?.trim();
    if (trimmed == null) return null;
    if (asUsername) {
      return trimmed.isNotEmpty && trimmed.runes.length <= 256
          ? EmailLoginIdentifier._(trimmed, EmailLoginIdentifierKind.username)
          : null;
    }
    final email = EmailAddress.tryParse(trimmed);
    if (email != null) {
      return EmailLoginIdentifier._(
        email.value,
        EmailLoginIdentifierKind.email,
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_!@#\$%^&*]{2,29}$').hasMatch(trimmed)) {
      return null;
    }
    return EmailLoginIdentifier._(trimmed, EmailLoginIdentifierKind.username);
  }

  final String value;
  final EmailLoginIdentifierKind kind;
}

// invalidEmail is retained for callers of the original email-only request
// flow; it now also covers an invalid username.
enum EmailLinkRequestStatus { accepted, invalidEmail, unavailable }

final class EmailLinkRequestResult {
  const EmailLinkRequestResult._({required this.status, this.identifier});

  const EmailLinkRequestResult.accepted(EmailLoginIdentifier identifier)
    : this._(status: EmailLinkRequestStatus.accepted, identifier: identifier);

  const EmailLinkRequestResult.invalidEmail()
    : this._(status: EmailLinkRequestStatus.invalidEmail);

  const EmailLinkRequestResult.unavailable()
    : this._(status: EmailLinkRequestStatus.unavailable);

  final EmailLinkRequestStatus status;
  final EmailLoginIdentifier? identifier;

  bool get isAccepted => status == EmailLinkRequestStatus.accepted;

  @override
  String toString() => 'EmailLinkRequestResult(status: $status)';
}

/// Opaque link material kept in memory between launch capture and POST
/// exchange. It intentionally redacts itself from all diagnostics and UI text.
final class EmailLinkToken {
  const EmailLinkToken._(this._value);

  static EmailLinkToken? tryParse(String? raw) {
    if (raw == null ||
        raw.isEmpty ||
        raw.length > 4096 ||
        raw.codeUnits.any((unit) => unit <= 0x20 || unit == 0x7f)) {
      return null;
    }
    return EmailLinkToken._(raw);
  }

  final String _value;

  /// The exchange adapter may read this only to construct the POST body.
  String get value => _value;

  @override
  bool operator ==(Object other) =>
      other is EmailLinkToken && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => '[redacted email-link token]';
}

enum EmailLinkLaunchStatus { captured, malformed, scrubFailed }

final class EmailLinkLaunchData {
  const EmailLinkLaunchData._({required this.status, this.token});

  const EmailLinkLaunchData.captured(EmailLinkToken token)
    : this._(status: EmailLinkLaunchStatus.captured, token: token);

  const EmailLinkLaunchData.malformed()
    : this._(status: EmailLinkLaunchStatus.malformed);

  const EmailLinkLaunchData.scrubFailed()
    : this._(status: EmailLinkLaunchStatus.scrubFailed);

  final EmailLinkLaunchStatus status;
  final EmailLinkToken? token;

  bool get hasUsableToken =>
      status == EmailLinkLaunchStatus.captured && token != null;

  @override
  String toString() => 'EmailLinkLaunchData(status: $status)';
}

/// Parses the public callback URL without performing any authentication work.
///
/// The token is expected in the one browser fragment owned by the hash router:
/// `/#/email-login/callback?token=...`. A second fragment, duplicate token
/// parameter, malformed query escape, or any other callback shape is rejected
/// before a launch adapter can hand data to the controller.
final class EmailLinkLaunchParser {
  const EmailLinkLaunchParser._();

  static const _callbackPath = '/email-login/callback';

  /// Identifies the one hash route owned by consumer email sign-in. It does
  /// not validate or redeem the query material; capture performs both parsing
  /// and browser-history scrubbing before the router is created.
  static bool isCallbackLocation(String? location) {
    if (location == null || location.isEmpty) return false;
    final hash = location.indexOf('#');
    if (hash < 0) return false;
    final fragment = location.substring(hash + 1);
    return fragment == _callbackPath || fragment.startsWith('$_callbackPath?');
  }

  static EmailLinkLaunchData parse(String? location) {
    if (location == null || location.isEmpty) {
      return const EmailLinkLaunchData.malformed();
    }

    final uri = Uri.tryParse(location);
    if (uri == null || uri.fragment.isEmpty) {
      return const EmailLinkLaunchData.malformed();
    }

    final hash = location.indexOf('#');
    final rawFragment = hash < 0 ? '' : location.substring(hash + 1);
    if (rawFragment.contains('#') ||
        RegExp('%23', caseSensitive: false).hasMatch(rawFragment) ||
        RegExp('%(?![0-9A-Fa-f]{2})').hasMatch(rawFragment)) {
      return const EmailLinkLaunchData.malformed();
    }

    final fragment = uri.fragment;
    if (fragment.contains('#') || !fragment.startsWith('$_callbackPath?')) {
      return const EmailLinkLaunchData.malformed();
    }

    final query = fragment.substring(_callbackPath.length + 1);
    final tokenValues = <String>[];
    if (query.isEmpty) {
      return const EmailLinkLaunchData.malformed();
    }
    for (final pair in query.split('&')) {
      if (pair.isEmpty) return const EmailLinkLaunchData.malformed();
      final separator = pair.indexOf('=');
      if (separator <= 0) return const EmailLinkLaunchData.malformed();
      final key = _decodeQueryPart(pair.substring(0, separator));
      final value = _decodeQueryPart(pair.substring(separator + 1));
      if (key == null || value == null) {
        return const EmailLinkLaunchData.malformed();
      }
      if (key != 'token') return const EmailLinkLaunchData.malformed();
      tokenValues.add(value);
    }

    if (tokenValues.length != 1) {
      return const EmailLinkLaunchData.malformed();
    }
    final token = EmailLinkToken.tryParse(tokenValues.single);
    return token == null
        ? const EmailLinkLaunchData.malformed()
        : EmailLinkLaunchData.captured(token);
  }

  static String? _decodeQueryPart(String value) {
    try {
      // Query components use form encoding. Opaque link tokens are expected
      // to be URL encoded when they contain a plus sign.
      return Uri.decodeQueryComponent(value);
    } on FormatException {
      return null;
    }
  }
}

/// Credentials are transient exchange output. They must never be persisted or
/// placed in a view state; their string form is safe for diagnostics.
final class EmailLoginCredentials {
  const EmailLoginCredentials({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;

  @override
  bool operator ==(Object other) =>
      other is EmailLoginCredentials &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, userId);

  @override
  String toString() =>
      'EmailLoginCredentials(userId: $userId, tokens: [redacted])';
}

final class EmailLinkExchange {
  const EmailLinkExchange({
    required this.credentials,
    required this.canonicalUsername,
  });

  final EmailLoginCredentials credentials;
  final String canonicalUsername;

  @override
  String toString() =>
      'EmailLinkExchange(username: $canonicalUsername, userId: '
      '${credentials.userId}, credentials: [redacted])';
}

enum EmailLinkExchangeStatus {
  success,
  invalid,
  expired,
  used,
  reused,
  unavailable,
}

final class EmailLinkExchangeResult {
  const EmailLinkExchangeResult._({required this.status, this.exchange});

  const EmailLinkExchangeResult.success(EmailLinkExchange exchange)
    : this._(status: EmailLinkExchangeStatus.success, exchange: exchange);

  const EmailLinkExchangeResult.invalid()
    : this._(status: EmailLinkExchangeStatus.invalid);

  const EmailLinkExchangeResult.expired()
    : this._(status: EmailLinkExchangeStatus.expired);

  const EmailLinkExchangeResult.used()
    : this._(status: EmailLinkExchangeStatus.used);

  /// The API may call a consumed link "reused". Keep this distinct from
  /// [used] so an adapter can preserve the typed wire outcome while the
  /// presentation maps both to one safe message.
  const EmailLinkExchangeResult.reused()
    : this._(status: EmailLinkExchangeStatus.reused);

  const EmailLinkExchangeResult.unavailable()
    : this._(status: EmailLinkExchangeStatus.unavailable);

  final EmailLinkExchangeStatus status;
  final EmailLinkExchange? exchange;

  bool get isSuccess => status == EmailLinkExchangeStatus.success;

  bool get isConsumed =>
      status == EmailLinkExchangeStatus.used ||
      status == EmailLinkExchangeStatus.reused;

  @override
  String toString() => 'EmailLinkExchangeResult(status: $status)';
}

final class EmailLoginSessionSnapshot {
  const EmailLoginSessionSnapshot({
    required this.userId,
    required this.generation,
    required this.cleanupRequired,
  });

  final String? userId;
  final int generation;
  final bool cleanupRequired;

  bool get isSignedIn => userId != null;

  @override
  String toString() =>
      'EmailLoginSessionSnapshot(userId: $userId, generation: $generation, '
      'cleanupRequired: $cleanupRequired)';
}

enum EmailLoginAdmissionStatus {
  accepted,
  staleGeneration,
  cleanupRequired,
  failed,
}

final class EmailLoginAdmissionResult {
  const EmailLoginAdmissionResult._(this.status);

  const EmailLoginAdmissionResult.accepted()
    : this._(EmailLoginAdmissionStatus.accepted);

  const EmailLoginAdmissionResult.staleGeneration()
    : this._(EmailLoginAdmissionStatus.staleGeneration);

  const EmailLoginAdmissionResult.cleanupRequired()
    : this._(EmailLoginAdmissionStatus.cleanupRequired);

  const EmailLoginAdmissionResult.failed()
    : this._(EmailLoginAdmissionStatus.failed);

  final EmailLoginAdmissionStatus status;

  bool get isAccepted => status == EmailLoginAdmissionStatus.accepted;

  @override
  String toString() => 'EmailLoginAdmissionResult(status: $status)';
}

final class RecoveryToken {
  const RecoveryToken._(this._value);

  static RecoveryToken? tryParse(String? raw) {
    if (raw == null ||
        raw.isEmpty ||
        raw.length > 4096 ||
        raw.codeUnits.any((unit) => unit <= 0x20 || unit == 0x7f)) {
      return null;
    }
    return RecoveryToken._(raw);
  }

  final String _value;

  String get value => _value;

  @override
  bool operator ==(Object other) =>
      other is RecoveryToken && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => '[redacted recovery token]';
}

final class RecoveryPassword {
  const RecoveryPassword._(this._value);

  static RecoveryPassword? tryParse(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > 256) return null;
    return RecoveryPassword._(raw);
  }

  final String _value;

  String get value => _value;

  @override
  String toString() => '[redacted recovery password]';
}

enum RecoveryCompletionStatus {
  completed,
  invalidPassword,
  invalidToken,
  expiredToken,
  usedToken,
  unavailable,
}

final class RecoveryCompletionResult {
  const RecoveryCompletionResult._(this.status);

  const RecoveryCompletionResult.completed()
    : this._(RecoveryCompletionStatus.completed);

  const RecoveryCompletionResult.invalidPassword()
    : this._(RecoveryCompletionStatus.invalidPassword);

  const RecoveryCompletionResult.invalidToken()
    : this._(RecoveryCompletionStatus.invalidToken);

  const RecoveryCompletionResult.expiredToken()
    : this._(RecoveryCompletionStatus.expiredToken);

  const RecoveryCompletionResult.usedToken()
    : this._(RecoveryCompletionStatus.usedToken);

  const RecoveryCompletionResult.unavailable()
    : this._(RecoveryCompletionStatus.unavailable);

  final RecoveryCompletionStatus status;

  @override
  String toString() => 'RecoveryCompletionResult(status: $status)';
}
