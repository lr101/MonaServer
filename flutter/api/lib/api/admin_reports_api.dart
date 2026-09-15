//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminReportsApi {
  AdminReportsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Add an administrative report note
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReportNoteRequestDto] adminReportNoteRequestDto (required):
  Future<Response> addAdminReportNoteWithHttpInfo(String reportId, String xCSRFToken, AdminReportNoteRequestDto adminReportNoteRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/reports/{reportId}/notes'
      .replaceAll('{reportId}', reportId);

    // ignore: prefer_final_locals
    Object? postBody = adminReportNoteRequestDto;

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

  /// Add an administrative report note
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReportNoteRequestDto] adminReportNoteRequestDto (required):
  Future<AdminReportNoteDto?> addAdminReportNote(String reportId, String xCSRFToken, AdminReportNoteRequestDto adminReportNoteRequestDto,) async {
    final response = await addAdminReportNoteWithHttpInfo(reportId, xCSRFToken, adminReportNoteRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminReportNoteDto',) as AdminReportNoteDto;
    
    }
    return null;
  }

  /// Read one report and its notes
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [int] revision:
  ///   Optional revision requested by the client.
  Future<Response> getAdminReportWithHttpInfo(String reportId, { int? revision, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/reports/{reportId}'
      .replaceAll('{reportId}', reportId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (revision != null) {
      queryParams.addAll(_queryParams('', 'revision', revision));
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

  /// Read one report and its notes
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [int] revision:
  ///   Optional revision requested by the client.
  Future<AdminReportDto?> getAdminReport(String reportId, { int? revision, }) async {
    final response = await getAdminReportWithHttpInfo(reportId,  revision: revision, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminReportDto',) as AdminReportDto;
    
    }
    return null;
  }

  /// List reports for administrative review
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
  /// * [AdminReportStatus] status:
  ///   Restrict reports to one review state.
  ///
  /// * [String] search:
  ///   Search bounded report text or target identity.
  Future<Response> listAdminReportsWithHttpInfo({ String? cursor, int? limit, AdminReportStatus? status, String? search, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/reports';

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
    if (status != null) {
      queryParams.addAll(_queryParams('', 'status', status));
    }
    if (search != null) {
      queryParams.addAll(_queryParams('', 'search', search));
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

  /// List reports for administrative review
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  ///
  /// * [AdminReportStatus] status:
  ///   Restrict reports to one review state.
  ///
  /// * [String] search:
  ///   Search bounded report text or target identity.
  Future<AdminReportPageDto?> listAdminReports({ String? cursor, int? limit, AdminReportStatus? status, String? search, }) async {
    final response = await listAdminReportsWithHttpInfo( cursor: cursor, limit: limit, status: status, search: search, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminReportPageDto',) as AdminReportPageDto;
    
    }
    return null;
  }

  /// Apply a revision-checked report transition
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReportUpdateRequestDto] adminReportUpdateRequestDto (required):
  Future<Response> updateAdminReportWithHttpInfo(String reportId, String xCSRFToken, AdminReportUpdateRequestDto adminReportUpdateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/reports/{reportId}'
      .replaceAll('{reportId}', reportId);

    // ignore: prefer_final_locals
    Object? postBody = adminReportUpdateRequestDto;

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

  /// Apply a revision-checked report transition
  ///
  /// Parameters:
  ///
  /// * [String] reportId (required):
  ///   Report identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [AdminReportUpdateRequestDto] adminReportUpdateRequestDto (required):
  Future<AdminReportDto?> updateAdminReport(String reportId, String xCSRFToken, AdminReportUpdateRequestDto adminReportUpdateRequestDto,) async {
    final response = await updateAdminReportWithHttpInfo(reportId, xCSRFToken, adminReportUpdateRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminReportDto',) as AdminReportDto;
    
    }
    return null;
  }
}
