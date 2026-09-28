import 'dart:async';

import 'package:app_links/app_links.dart';

/// Starts listening as soon as the app asks for its cold-start link, retaining
/// links received while storage and the rest of the app are bootstrapping.
final class NativeAppLinkSource {
  NativeAppLinkSource._() {
    _appLinks.uriLinkStream.listen(_receive, onError: (Object _) {});
  }

  static final NativeAppLinkSource instance = NativeAppLinkSource._();

  final AppLinks _appLinks = AppLinks();
  final StreamController<Uri> _events = StreamController<Uri>();
  final List<Uri> _buffered = [];
  Future<Uri?>? _initialization;
  Uri? _initialUri;
  bool _initialized = false;
  bool _initialEventPending = false;

  Stream<Uri> get events => _events.stream;

  Future<Uri?> getInitialLink() => _initialization ??= _readInitialLink();

  Future<Uri?> _readInitialLink() async {
    try {
      _initialUri = await _appLinks.getInitialLink();
    } catch (_) {
      _initialUri = null;
    }

    _initialized = true;
    _initialEventPending = _initialUri != null;
    for (final link in _buffered) {
      if (_initialEventPending && link == _initialUri) {
        _initialEventPending = false;
        continue;
      }
      _events.add(link);
    }
    _buffered.clear();
    return _initialUri;
  }

  void _receive(Uri link) {
    if (!_initialized) {
      _buffered.add(link);
      return;
    }
    if (_initialEventPending && link == _initialUri) {
      _initialEventPending = false;
      return;
    }
    _events.add(link);
  }
}
