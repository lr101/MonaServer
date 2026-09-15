//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminAudiencesApi {
  AdminAudiencesApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Read an administrative audience snapshot
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] audienceId (required):
  ///   Immutable audience snapshot identifier.
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  Future<Response> getAdminAudienceWithHttpInfo(String audienceId, { String? cursor, int? limit, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/audiences/{audienceId}'
      .replaceAll('{audienceId}', audienceId);

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

  /// Read an administrative audience snapshot
  ///
  /// Parameters:
  ///
  /// * [String] audienceId (required):
  ///   Immutable audience snapshot identifier.
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  Future<AdminAudiencePageDto?> getAdminAudience(String audienceId, { String? cursor, int? limit, }) async {
    final response = await getAdminAudienceWithHttpInfo(audienceId,  cursor: cursor, limit: limit, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminAudiencePageDto',) as AdminAudiencePageDto;
    
    }
    return null;
  }

  /// Preview an explicit administrative audience
  ///
  /// Resolve an explicit account or report audience into an immutable actor/action/payload-bound snapshot.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminAudiencePreviewRequestDto] adminAudiencePreviewRequestDto (required):
  Future<Response> previewAdminAudienceWithHttpInfo(String xCSRFToken, AdminAudiencePreviewRequestDto adminAudiencePreviewRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/audiences/preview';

    // ignore: prefer_final_locals
    Object? postBody = adminAudiencePreviewRequestDto;

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

  /// Preview an explicit administrative audience
  ///
  /// Resolve an explicit account or report audience into an immutable actor/action/payload-bound snapshot.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminAudiencePreviewRequestDto] adminAudiencePreviewRequestDto (required):
  Future<AdminAudiencePreviewDto?> previewAdminAudience(String xCSRFToken, AdminAudiencePreviewRequestDto adminAudiencePreviewRequestDto,) async {
    final response = await previewAdminAudienceWithHttpInfo(xCSRFToken, adminAudiencePreviewRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminAudiencePreviewDto',) as AdminAudiencePreviewDto;
    
    }
    return null;
  }
}
