import 'dart:js_interop';

import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';

/// Captures the browser location once and removes a valid callback fragment
/// before routing can retain an opaque token in browser history.
class WebEmailLinkLaunchPort implements EmailLinkLaunchPort {
  WebEmailLinkLaunchPort() : _location = _browserLocationHref.toDart;

  final String _location;
  bool? _scrubbed;

  @override
  String get location => _location;

  @override
  Future<bool> scrub() async {
    final previous = _scrubbed;
    if (previous != null) return previous;
    final uri = Uri.tryParse(_location);
    if (uri == null) return _scrubbed = false;
    if (!_isEmailLoginCallback(uri.fragment)) {
      _scrubbed = true;
      return true;
    }
    try {
      _replaceBrowserLocation(
        null,
        ''.toJS,
        uri.replace(fragment: '').toString().toJS,
      );
      _scrubbed =
          Uri.tryParse(_browserLocationHref.toDart)?.fragment.isEmpty == true;
    } catch (_) {
      _scrubbed = false;
    }
    return _scrubbed!;
  }
}

bool _isEmailLoginCallback(String fragment) =>
    fragment == '/email-login/callback' ||
    fragment.startsWith('/email-login/callback?');

EmailLinkLaunchPort createEmailLinkLaunchPort() => WebEmailLinkLaunchPort();

@JS('window.location.href')
external JSString get _browserLocationHref;

@JS('window.history.replaceState')
external void _replaceBrowserLocation(
  JSAny? state,
  JSString title,
  JSString location,
);
