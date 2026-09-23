import 'package:buff_lisa/app/routing/session_redirect.dart';
import 'package:buff_lisa/core/session/session_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in [SessionStatus.signedOut, SessionStatus.expired]) {
    test('$status redirects protected routes to login without cleanup', () {
      for (final location in ['/home', '/settings', '/groups/example']) {
        expect(
          sessionRedirect(
            status: status,
            cleanupRequired: false,
            location: location,
          ),
          '/login',
        );
      }
      for (final location in ['/login', '/web', '/logout']) {
        expect(
          sessionRedirect(
            status: status,
            cleanupRequired: false,
            location: location,
          ),
          isNull,
        );
      }
    });
  }
  test(
    'pending cleanup takes precedence over both login and expired state',
    () {
      for (final status in SessionStatus.values) {
        expect(
          sessionRedirect(
            status: status,
            cleanupRequired: true,
            location: '/login',
          ),
          '/logout',
        );
        expect(
          sessionRedirect(
            status: status,
            cleanupRequired: true,
            location: '/logout',
          ),
          isNull,
        );
      }
    },
  );
  test(
    'authenticated sessions leave login and retain protected destinations',
    () {
      expect(
        sessionRedirect(
          status: SessionStatus.signedIn,
          cleanupRequired: false,
          location: '/login',
        ),
        '/home',
      );
      expect(
        sessionRedirect(
          status: SessionStatus.signedIn,
          cleanupRequired: false,
          location: '/groups/example',
        ),
        isNull,
      );
    },
  );

  test('email-login routes remain public while signed out', () {
    for (final status in [SessionStatus.signedOut, SessionStatus.expired]) {
      for (final location in ['/email-login', '/email-login/callback']) {
        expect(
          sessionRedirect(
            status: status,
            cleanupRequired: false,
            location: location,
          ),
          isNull,
        );
      }
    }
  });

  test(
    'cleanup redirects email callbacks through the existing logout flow',
    () {
      expect(
        sessionRedirect(
          status: SessionStatus.signedOut,
          cleanupRequired: true,
          location: '/email-login/callback',
        ),
        '/logout',
      );
    },
  );
}
