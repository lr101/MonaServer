//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminSessionApi {
  AdminSessionApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Begin an admin password and MFA login
  ///
  /// Start the password challenge; this endpoint never issues a consumer JWT or refresh token.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminSessionLoginRequestDto] adminSessionLoginRequestDto (required):
  Future<Response> adminSessionLoginWithHttpInfo(String xCSRFToken, AdminSessionLoginRequestDto adminSessionLoginRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/login';

    // ignore: prefer_final_locals
    Object? postBody = adminSessionLoginRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Begin an admin password and MFA login
  ///
  /// Start the password challenge; this endpoint never issues a consumer JWT or refresh token.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminSessionLoginRequestDto] adminSessionLoginRequestDto (required):
  Future<AdminSessionLoginResponseDto?> adminSessionLogin(String xCSRFToken, AdminSessionLoginRequestDto adminSessionLoginRequestDto,) async {
    final response = await adminSessionLoginWithHttpInfo(xCSRFToken, adminSessionLoginRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionLoginResponseDto',) as AdminSessionLoginResponseDto;

    }
    return null;
  }

  /// Bootstrap an admin browser session
  ///
  /// Create or refresh a pre-authentication browser session and issue a CSRF token bound to its challenge.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> bootstrapAdminSessionWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/bootstrap';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Bootstrap an admin browser session
  ///
  /// Create or refresh a pre-authentication browser session and issue a CSRF token bound to its challenge.
  Future<AdminSessionBootstrapDto?> bootstrapAdminSession() async {
    final response = await bootstrapAdminSessionWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionBootstrapDto',) as AdminSessionBootstrapDto;

    }
    return null;
  }

  /// Complete admin MFA
  ///
  /// Complete the one-use MFA challenge and rotate the CSRF token on authentication.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminMfaRequestDto] adminMfaRequestDto (required):
  Future<Response> completeAdminSessionMfaWithHttpInfo(String xCSRFToken, AdminMfaRequestDto adminMfaRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/mfa';

    // ignore: prefer_final_locals
    Object? postBody = adminMfaRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Complete admin MFA
  ///
  /// Complete the one-use MFA challenge and rotate the CSRF token on authentication.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminMfaRequestDto] adminMfaRequestDto (required):
  Future<AdminSessionDto?> completeAdminSessionMfa(String xCSRFToken, AdminMfaRequestDto adminMfaRequestDto,) async {
    final response = await completeAdminSessionMfaWithHttpInfo(xCSRFToken, adminMfaRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionDto',) as AdminSessionDto;

    }
    return null;
  }

  /// Restore the current admin session
  ///
  /// Restore the current admin session and capabilities after a page reload.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getAdminSessionWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Restore the current admin session
  ///
  /// Restore the current admin session and capabilities after a page reload.
  Future<AdminSessionDto?> getAdminSession() async {
    final response = await getAdminSessionWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionDto',) as AdminSessionDto;

    }
    return null;
  }

  /// Set up the first administrator
  ///
  /// Claim one-time first administrator enrollment for an existing password account using a deployment secret and pre-authentication CSRF token. Returns the TOTP secret only once.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminInitialSetupRequestDto] adminInitialSetupRequestDto (required):
  Future<Response> initialAdminSetupWithHttpInfo(String xCSRFToken, AdminInitialSetupRequestDto adminInitialSetupRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/initial-setup';

    // ignore: prefer_final_locals
    Object? postBody = adminInitialSetupRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Set up the first administrator
  ///
  /// Claim one-time first administrator enrollment for an existing password account using a deployment secret and pre-authentication CSRF token. Returns the TOTP secret only once.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminInitialSetupRequestDto] adminInitialSetupRequestDto (required):
  Future<AdminInitialSetupResponseDto?> initialAdminSetup(String xCSRFToken, AdminInitialSetupRequestDto adminInitialSetupRequestDto,) async {
    final response = await initialAdminSetupWithHttpInfo(xCSRFToken, adminInitialSetupRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminInitialSetupResponseDto',) as AdminInitialSetupResponseDto;

    }
    return null;
  }

  /// Log out of the admin session
  ///
  /// Revoke the opaque admin session and clear its browser cookie.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<Response> logoutAdminSessionWithHttpInfo(String xCSRFToken,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/logout';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Log out of the admin session
  ///
  /// Revoke the opaque admin session and clear its browser cookie.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<void> logoutAdminSession(String xCSRFToken,) async {
    final response = await logoutAdminSessionWithHttpInfo(xCSRFToken,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Reauthenticate an admin session for a sensitive action
  ///
  /// Refresh recent MFA freshness for a specific action and rotate the CSRF token.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReauthenticateRequestDto] adminReauthenticateRequestDto (required):
  Future<Response> reauthenticateAdminSessionWithHttpInfo(String xCSRFToken, AdminReauthenticateRequestDto adminReauthenticateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/session/reauthenticate';

    // ignore: prefer_final_locals
    Object? postBody = adminReauthenticateRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Reauthenticate an admin session for a sensitive action
  ///
  /// Refresh recent MFA freshness for a specific action and rotate the CSRF token.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReauthenticateRequestDto] adminReauthenticateRequestDto (required):
  Future<AdminSessionDto?> reauthenticateAdminSession(String xCSRFToken, AdminReauthenticateRequestDto adminReauthenticateRequestDto,) async {
    final response = await reauthenticateAdminSessionWithHttpInfo(xCSRFToken, adminReauthenticateRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminSessionDto',) as AdminSessionDto;

    }
    return null;
  }
}
