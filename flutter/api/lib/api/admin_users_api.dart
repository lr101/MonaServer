//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminUsersApi {
  AdminUsersApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get one administrative user record
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  Future<Response> getAdminUserWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/users/{userId}'
      .replaceAll('{userId}', userId);

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

  /// Get one administrative user record
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  Future<AdminUserDetailsDto?> getAdminUser(String userId,) async {
    final response = await getAdminUserWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUserDetailsDto',) as AdminUserDetailsDto;

    }
    return null;
  }

  /// Search administrative user records
  ///
  /// Return bounded account records without tokens, password hashes, or other credential material.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  ///
  /// * [String] search:
  ///   Case-insensitive username, email, or stable ID search.
  ///
  /// * [AdminSecurityState] securityStatus:
  ///   Restrict results to one security state.
  ///
  /// * [bool] verifiedEmail:
  ///   Restrict results by verified-email presence.
  ///
  /// * [DateTime] createdAfter:
  ///   Include accounts created at or after this instant.
  ///
  /// * [DateTime] createdBefore:
  ///   Include accounts created before this instant.
  Future<Response> listAdminUsersWithHttpInfo({ String? cursor, int? limit, String? search, AdminSecurityState? securityStatus, bool? verifiedEmail, DateTime? createdAfter, DateTime? createdBefore, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/users';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (cursor != null) {
      queryParams.addAll(_queryParams('', 'cursor', cursor));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (search != null) {
      queryParams.addAll(_queryParams('', 'search', search));
    }
    if (securityStatus != null) {
      queryParams.addAll(_queryParams('', 'securityStatus', securityStatus));
    }
    if (verifiedEmail != null) {
      queryParams.addAll(_queryParams('', 'verifiedEmail', verifiedEmail));
    }
    if (createdAfter != null) {
      queryParams.addAll(_queryParams('', 'createdAfter', createdAfter));
    }
    if (createdBefore != null) {
      queryParams.addAll(_queryParams('', 'createdBefore', createdBefore));
    }

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

  /// Search administrative user records
  ///
  /// Return bounded account records without tokens, password hashes, or other credential material.
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  ///
  /// * [String] search:
  ///   Case-insensitive username, email, or stable ID search.
  ///
  /// * [AdminSecurityState] securityStatus:
  ///   Restrict results to one security state.
  ///
  /// * [bool] verifiedEmail:
  ///   Restrict results by verified-email presence.
  ///
  /// * [DateTime] createdAfter:
  ///   Include accounts created at or after this instant.
  ///
  /// * [DateTime] createdBefore:
  ///   Include accounts created before this instant.
  Future<AdminUserPageDto?> listAdminUsers({ String? cursor, int? limit, String? search, AdminSecurityState? securityStatus, bool? verifiedEmail, DateTime? createdAfter, DateTime? createdBefore, }) async {
    final response = await listAdminUsersWithHttpInfo( cursor: cursor, limit: limit, search: search, securityStatus: securityStatus, verifiedEmail: verifiedEmail, createdAfter: createdAfter, createdBefore: createdBefore, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUserPageDto',) as AdminUserPageDto;

    }
    return null;
  }

  /// Queue a one-time login link to one user's verified email
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<Response> sendAdminUserLoginLinkWithHttpInfo(String userId, String xCSRFToken,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/users/{userId}/login-link'
      .replaceAll('{userId}', userId);

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

  /// Queue a one-time login link to one user's verified email
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<void> sendAdminUserLoginLink(String userId, String xCSRFToken,) async {
    final response = await sendAdminUserLoginLinkWithHttpInfo(userId, xCSRFToken,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Send one user's password recovery email as an administrator
  ///
  /// Send a password recovery email to one user's verified email. The user's current password remains active until they complete recovery. Requires recent MFA bound to security.recovery_resend.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<Response> sendAdminUserPasswordResetLinkWithHttpInfo(String userId, String xCSRFToken,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/users/{userId}/password-reset'
      .replaceAll('{userId}', userId);

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

  /// Send one user's password recovery email as an administrator
  ///
  /// Send a password recovery email to one user's verified email. The user's current password remains active until they complete recovery. Requires recent MFA bound to security.recovery_resend.
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<void> sendAdminUserPasswordResetLink(String userId, String xCSRFToken,) async {
    final response = await sendAdminUserPasswordResetLinkWithHttpInfo(userId, xCSRFToken,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Verify one user email as an administrator
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<Response> verifyAdminUserEmailWithHttpInfo(String userId, String xCSRFToken,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/users/{userId}/verify-email'
      .replaceAll('{userId}', userId);

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

  /// Verify one user email as an administrator
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///   Stable account identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  Future<AdminUserDetailsDto?> verifyAdminUserEmail(String userId, String xCSRFToken,) async {
    final response = await verifyAdminUserEmailWithHttpInfo(userId, xCSRFToken,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminUserDetailsDto',) as AdminUserDetailsDto;

    }
    return null;
  }
}
