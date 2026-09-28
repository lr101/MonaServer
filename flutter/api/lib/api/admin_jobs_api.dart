//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminJobsApi {
  AdminJobsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Cancel pending job work
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCommandRequestDto] adminJobCommandRequestDto (required):
  Future<Response> cancelAdminJobWithHttpInfo(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs/{jobId}/cancel'
      .replaceAll('{jobId}', jobId);

    // ignore: prefer_final_locals
    Object? postBody = adminJobCommandRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);
    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

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

  /// Cancel pending job work
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCommandRequestDto] adminJobCommandRequestDto (required):
  Future<AdminJobAcceptedDto?> cancelAdminJob(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto,) async {
    final response = await cancelAdminJobWithHttpInfo(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobAcceptedDto',) as AdminJobAcceptedDto;
    
    }
    return null;
  }

  /// Commit an administrative action job
  ///
  /// Commit exactly one unexpired preview snapshot and action. The Idempotency-Key header is required.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCreateRequestDto] adminJobCreateRequestDto (required):
  Future<Response> createAdminJobWithHttpInfo(String xCSRFToken, String idempotencyKey, AdminJobCreateRequestDto adminJobCreateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs';

    // ignore: prefer_final_locals
    Object? postBody = adminJobCreateRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);
    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

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

  /// Commit an administrative action job
  ///
  /// Commit exactly one unexpired preview snapshot and action. The Idempotency-Key header is required.
  ///
  /// Parameters:
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCreateRequestDto] adminJobCreateRequestDto (required):
  Future<AdminJobAcceptedDto?> createAdminJob(String xCSRFToken, String idempotencyKey, AdminJobCreateRequestDto adminJobCreateRequestDto,) async {
    final response = await createAdminJobWithHttpInfo(xCSRFToken, idempotencyKey, adminJobCreateRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobAcceptedDto',) as AdminJobAcceptedDto;
    
    }
    return null;
  }

  /// Read an administrative job
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  Future<Response> getAdminJobWithHttpInfo(String jobId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs/{jobId}'
      .replaceAll('{jobId}', jobId);

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

  /// Read an administrative job
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  Future<AdminJobDto?> getAdminJob(String jobId,) async {
    final response = await getAdminJobWithHttpInfo(jobId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobDto',) as AdminJobDto;
    
    }
    return null;
  }

  /// List job recipient outcomes
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  Future<Response> listAdminJobRecipientsWithHttpInfo(String jobId, { String? cursor, int? limit, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs/{jobId}/recipients'
      .replaceAll('{jobId}', jobId);

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

  /// List job recipient outcomes
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  Future<AdminJobRecipientPageDto?> listAdminJobRecipients(String jobId, { String? cursor, int? limit, }) async {
    final response = await listAdminJobRecipientsWithHttpInfo(jobId,  cursor: cursor, limit: limit, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobRecipientPageDto',) as AdminJobRecipientPageDto;
    
    }
    return null;
  }

  /// List administrative action jobs
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
  /// * [AdminJobStatus] status:
  ///   Restrict jobs to a lifecycle state.
  ///
  /// * [AdminActionKind] action:
  ///   Restrict jobs to one action.
  Future<Response> listAdminJobsWithHttpInfo({ String? cursor, int? limit, AdminJobStatus? status, AdminActionKind? action, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs';

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
    if (action != null) {
      queryParams.addAll(_queryParams('', 'action', action));
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

  /// List administrative action jobs
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  ///
  /// * [AdminJobStatus] status:
  ///   Restrict jobs to a lifecycle state.
  ///
  /// * [AdminActionKind] action:
  ///   Restrict jobs to one action.
  Future<AdminJobPageDto?> listAdminJobs({ String? cursor, int? limit, AdminJobStatus? status, AdminActionKind? action, }) async {
    final response = await listAdminJobsWithHttpInfo( cursor: cursor, limit: limit, status: status, action: action, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobPageDto',) as AdminJobPageDto;
    
    }
    return null;
  }

  /// Retry eligible failed job work
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCommandRequestDto] adminJobCommandRequestDto (required):
  Future<Response> retryAdminJobWithHttpInfo(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/jobs/{jobId}/retry'
      .replaceAll('{jobId}', jobId);

    // ignore: prefer_final_locals
    Object? postBody = adminJobCommandRequestDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    headerParams[r'X-CSRF-Token'] = parameterToString(xCSRFToken);
    headerParams[r'Idempotency-Key'] = parameterToString(idempotencyKey);

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

  /// Retry eligible failed job work
  ///
  /// Parameters:
  ///
  /// * [String] jobId (required):
  ///   Durable job identifier.
  ///
  /// * [String] xCSRFToken (required):
  ///   Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
  ///
  /// * [String] idempotencyKey (required):
  ///   Client-generated business key; reusing it with a different payload returns 409.
  ///
  /// * [AdminJobCommandRequestDto] adminJobCommandRequestDto (required):
  Future<AdminJobAcceptedDto?> retryAdminJob(String jobId, String xCSRFToken, String idempotencyKey, AdminJobCommandRequestDto adminJobCommandRequestDto,) async {
    final response = await retryAdminJobWithHttpInfo(jobId, xCSRFToken, idempotencyKey, adminJobCommandRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminJobAcceptedDto',) as AdminJobAcceptedDto;
    
    }
    return null;
  }
}
