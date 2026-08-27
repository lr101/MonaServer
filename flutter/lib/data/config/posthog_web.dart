import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _globalThis;

Future<void> initializePosthogWeb({
  required String apiKey,
  required String host,
  required bool debug,
}) async {
  final posthog = _globalThis.getProperty<JSObject?>('posthog'.toJS);
  if (posthog == null) return;

  final options = JSObject()
    ..setProperty('api_host'.toJS, host.toJS)
    ..setProperty('capture_pageview'.toJS, false.toJS)
    ..setProperty('capture_pageleave'.toJS, false.toJS)
    ..setProperty('debug'.toJS, debug.toJS);

  posthog.callMethod<JSAny?>('init'.toJS, apiKey.toJS, options);
}
