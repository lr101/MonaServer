//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class BatchApi {
  BatchApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Read several authenticated resources in one request
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [BatchReadRequest] batchReadRequest (required):
  Future<Response> batchReadWithHttpInfo(BatchReadRequest batchReadRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/batch';

    // ignore: prefer_final_locals
    Object? postBody = batchReadRequest;

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

  /// Read several authenticated resources in one request
  ///
  /// Parameters:
  ///
  /// * [BatchReadRequest] batchReadRequest (required):
  Future<BatchReadResponse?> batchRead(BatchReadRequest batchReadRequest,) async {
    final response = await batchReadWithHttpInfo(batchReadRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'BatchReadResponse',) as BatchReadResponse;
    
    }
    return null;
  }
}
