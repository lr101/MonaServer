//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminCampaignsApi {
  AdminCampaignsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Archive a campaign
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignRevisionRequestDto] adminCampaignRevisionRequestDto (required):
  Future<Response> archiveAdminCampaignWithHttpInfo(String campaignId, String xCSRFToken, AdminCampaignRevisionRequestDto adminCampaignRevisionRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns/{campaignId}/archive'
      .replaceAll('{campaignId}', campaignId);

    // ignore: prefer_final_locals
    Object? postBody = adminCampaignRevisionRequestDto;

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

  /// Archive a campaign
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignRevisionRequestDto] adminCampaignRevisionRequestDto (required):
  Future<AdminCampaignDto?> archiveAdminCampaign(String campaignId, String xCSRFToken, AdminCampaignRevisionRequestDto adminCampaignRevisionRequestDto,) async {
    final response = await archiveAdminCampaignWithHttpInfo(campaignId, xCSRFToken, adminCampaignRevisionRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminCampaignDto',) as AdminCampaignDto;

    }
    return null;
  }

  /// Create a content-only campaign
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignCreateRequestDto] adminCampaignCreateRequestDto (required):
  Future<Response> createAdminCampaignWithHttpInfo(String xCSRFToken, AdminCampaignCreateRequestDto adminCampaignCreateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns';

    // ignore: prefer_final_locals
    Object? postBody = adminCampaignCreateRequestDto;

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

  /// Create a content-only campaign
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignCreateRequestDto] adminCampaignCreateRequestDto (required):
  Future<AdminCampaignDto?> createAdminCampaign(String xCSRFToken, AdminCampaignCreateRequestDto adminCampaignCreateRequestDto,) async {
    final response = await createAdminCampaignWithHttpInfo(xCSRFToken, adminCampaignCreateRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminCampaignDto',) as AdminCampaignDto;

    }
    return null;
  }

  /// Delete a draft campaign
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignRevisionRequestDto] adminCampaignRevisionRequestDto (required):
  Future<Response> deleteAdminCampaignWithHttpInfo(String campaignId, String xCSRFToken, AdminCampaignRevisionRequestDto adminCampaignRevisionRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns/{campaignId}'
      .replaceAll('{campaignId}', campaignId);

    // ignore: prefer_final_locals
    Object? postBody = adminCampaignRevisionRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Delete a draft campaign
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignRevisionRequestDto] adminCampaignRevisionRequestDto (required):
  Future<void> deleteAdminCampaign(String campaignId, String xCSRFToken, AdminCampaignRevisionRequestDto adminCampaignRevisionRequestDto,) async {
    final response = await deleteAdminCampaignWithHttpInfo(campaignId, xCSRFToken, adminCampaignRevisionRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get a content-only campaign
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  Future<Response> getAdminCampaignWithHttpInfo(String campaignId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns/{campaignId}'
      .replaceAll('{campaignId}', campaignId);

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

  /// Get a content-only campaign
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  Future<AdminCampaignDto?> getAdminCampaign(String campaignId,) async {
    final response = await getAdminCampaignWithHttpInfo(campaignId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminCampaignDto',) as AdminCampaignDto;

    }
    return null;
  }

  /// List content-only campaigns
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
  Future<Response> listAdminCampaignsWithHttpInfo({ String? cursor, int? limit, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns';

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

  /// List content-only campaigns
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  Future<AdminCampaignPageDto?> listAdminCampaigns({ String? cursor, int? limit, }) async {
    final response = await listAdminCampaignsWithHttpInfo( cursor: cursor, limit: limit, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminCampaignPageDto',) as AdminCampaignPageDto;

    }
    return null;
  }

  /// Update a content-only campaign
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignUpdateRequestDto] adminCampaignUpdateRequestDto (required):
  Future<Response> updateAdminCampaignWithHttpInfo(String campaignId, String xCSRFToken, AdminCampaignUpdateRequestDto adminCampaignUpdateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/campaigns/{campaignId}'
      .replaceAll('{campaignId}', campaignId);

    // ignore: prefer_final_locals
    Object? postBody = adminCampaignUpdateRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update a content-only campaign
  ///
  /// Parameters:
  ///
  /// * [String] campaignId (required):
  ///   Stable campaign identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminCampaignUpdateRequestDto] adminCampaignUpdateRequestDto (required):
  Future<AdminCampaignDto?> updateAdminCampaign(String campaignId, String xCSRFToken, AdminCampaignUpdateRequestDto adminCampaignUpdateRequestDto,) async {
    final response = await updateAdminCampaignWithHttpInfo(campaignId, xCSRFToken, adminCampaignUpdateRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminCampaignDto',) as AdminCampaignDto;

    }
    return null;
  }
}
