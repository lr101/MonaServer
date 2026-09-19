import 'package:http/http.dart' as http;

import 'admin_http_client_stub.dart'
    if (dart.library.js_interop) 'admin_http_client_web.dart'
    as platform;

/// Creates an owned client for admin requests. The web implementation opts
/// into cookie credentials; the native implementation remains available for
/// local tests without importing browser-only libraries.
http.Client createAdminHttpClient() => platform.createAdminHttpClient();
