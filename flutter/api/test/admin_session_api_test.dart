//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

import 'package:openapi/api.dart';
import 'package:test/test.dart';


/// tests for AdminSessionApi
void main() {
  // final instance = AdminSessionApi();

  group('tests for AdminSessionApi', () {
    // Begin an admin password and MFA login
    //
    // Start the password challenge; this endpoint never issues a consumer JWT or refresh token.
    //
    //Future<AdminSessionLoginResponseDto> adminSessionLogin(String xCSRFToken, AdminSessionLoginRequestDto adminSessionLoginRequestDto) async
    test('test adminSessionLogin', () async {
      // TODO
    });

    // Bootstrap an admin browser session
    //
    // Create or refresh a pre-authentication browser session and issue a CSRF token bound to its challenge.
    //
    //Future<AdminSessionBootstrapDto> bootstrapAdminSession() async
    test('test bootstrapAdminSession', () async {
      // TODO
    });

    // Complete admin MFA
    //
    // Complete the one-use MFA challenge and rotate the CSRF token on authentication.
    //
    //Future<AdminSessionDto> completeAdminSessionMfa(String xCSRFToken, AdminMfaRequestDto adminMfaRequestDto) async
    test('test completeAdminSessionMfa', () async {
      // TODO
    });

    // Restore the current admin session
    //
    // Restore the current admin session and capabilities after a page reload.
    //
    //Future<AdminSessionDto> getAdminSession() async
    test('test getAdminSession', () async {
      // TODO
    });

    // Log out of the admin session
    //
    // Revoke the opaque admin session and clear its browser cookie.
    //
    //Future logoutAdminSession(String xCSRFToken) async
    test('test logoutAdminSession', () async {
      // TODO
    });

    // Reauthenticate an admin session for a sensitive action
    //
    // Refresh recent MFA freshness for a specific action and rotate the CSRF token.
    //
    //Future<AdminSessionDto> reauthenticateAdminSession(String xCSRFToken, AdminReauthenticateRequestDto adminReauthenticateRequestDto) async
    test('test reauthenticateAdminSession', () async {
      // TODO
    });

  });
}
