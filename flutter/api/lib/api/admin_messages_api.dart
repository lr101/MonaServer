//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminMessagesApi {
  AdminMessagesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Send an administrative test message
  ///
  /// Validate a message and deliver only to the explicit test recipient; action tokens are never returned.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminTestMessageRequestDto] adminTestMessageRequestDto (required):
  Future<Response> sendAdminTestMessageWithHttpInfo(String xCSRFToken, AdminTestMessageRequestDto adminTestMessageRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/messages/test';

    // ignore: prefer_final_locals
    Object? postBody = adminTestMessageRequestDto;

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

  /// Send an administrative test message
  ///
  /// Validate a message and deliver only to the explicit test recipient; action tokens are never returned.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminTestMessageRequestDto] adminTestMessageRequestDto (required):
  Future<AdminTestMessageAcceptedDto?> sendAdminTestMessage(String xCSRFToken, AdminTestMessageRequestDto adminTestMessageRequestDto,) async {
    final response = await sendAdminTestMessageWithHttpInfo(xCSRFToken, adminTestMessageRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminTestMessageAcceptedDto',) as AdminTestMessageAcceptedDto;
    
    }
    return null;
  }
}
