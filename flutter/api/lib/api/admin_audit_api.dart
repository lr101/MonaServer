//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminAuditApi {
  AdminAuditApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// List administrative audit events
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
  /// * [String] targetUserId:
  ///   Restrict events to one target account.
  ///
  /// * [AdminActionKind] action:
  ///   Restrict events to one action.
  Future<Response> listAdminAuditWithHttpInfo({ String? cursor, int? limit, String? targetUserId, AdminActionKind? action, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/admin/audit';

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
    if (targetUserId != null) {
      queryParams.addAll(_queryParams('', 'targetUserId', targetUserId));
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

  /// List administrative audit events
  ///
  /// Parameters:
  ///
  /// * [String] cursor:
  ///   Opaque cursor returned by the preceding page.
  ///
  /// * [int] limit:
  ///   Maximum number of records in the page; defaults to 25 and is capped at 100.
  ///
  /// * [String] targetUserId:
  ///   Restrict events to one target account.
  ///
  /// * [AdminActionKind] action:
  ///   Restrict events to one action.
  Future<AdminAuditPageDto?> listAdminAudit({ String? cursor, int? limit, String? targetUserId, AdminActionKind? action, }) async {
    final response = await listAdminAuditWithHttpInfo( cursor: cursor, limit: limit, targetUserId: targetUserId, action: action, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'AdminAuditPageDto',) as AdminAuditPageDto;
    
    }
    return null;
  }
}
