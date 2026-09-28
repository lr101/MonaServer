//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class SessionAuthApi {
  SessionAuthApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Revoke the caller's submitted refresh credential
  ///
  /// Revoke only the submitted refresh credential when it belongs to the bearer-authenticated caller.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [SessionRevokeRequestDto] sessionRevokeRequestDto (required):
  Future<Response> revokeOwnSessionWithHttpInfo(SessionRevokeRequestDto sessionRevokeRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/auth/session/revoke';

    // ignore: prefer_final_locals
    Object? postBody = sessionRevokeRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Revoke the caller's submitted refresh credential
  ///
  /// Revoke only the submitted refresh credential when it belongs to the bearer-authenticated caller.
  ///
  /// Parameters:
  ///
  /// * [SessionRevokeRequestDto] sessionRevokeRequestDto (required):
  Future<void> revokeOwnSession(SessionRevokeRequestDto sessionRevokeRequestDto,) async {
    final response = await revokeOwnSessionWithHttpInfo(sessionRevokeRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
