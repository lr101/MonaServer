//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupPinDesignsApi {
  GroupPinDesignsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Get the pin designs available for a group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<Response> getGroupPinDesignCatalogWithHttpInfo(
    String groupId,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/pin-designs'
        .replaceAll('{groupId}', groupId);

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

  /// Get the pin designs available for a group
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  Future<GroupPinDesignCatalogDto?> getGroupPinDesignCatalog(
    String groupId,
  ) async {
    final response = await getGroupPinDesignCatalogWithHttpInfo(
      groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'GroupPinDesignCatalogDto',
      ) as GroupPinDesignCatalogDto;
    }
    return null;
  }

  /// Update a group's earned pin design
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [UpdateGroupPinDesignCatalogDto] updateGroupPinDesignCatalogDto (required):
  Future<Response> updateGroupPinDesignCatalogWithHttpInfo(
    String groupId,
    UpdateGroupPinDesignCatalogDto updateGroupPinDesignCatalogDto,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/groups/{groupId}/pin-designs'
        .replaceAll('{groupId}', groupId);

    // ignore: prefer_final_locals
    Object? postBody = updateGroupPinDesignCatalogDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update a group's earned pin design
  ///
  /// Parameters:
  ///
  /// * [String] groupId (required):
  ///
  /// * [UpdateGroupPinDesignCatalogDto] updateGroupPinDesignCatalogDto (required):
  Future<GroupPinDesignCatalogDto?> updateGroupPinDesignCatalog(
    String groupId,
    UpdateGroupPinDesignCatalogDto updateGroupPinDesignCatalogDto,
  ) async {
    final response = await updateGroupPinDesignCatalogWithHttpInfo(
      groupId,
      updateGroupPinDesignCatalogDto,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'GroupPinDesignCatalogDto',
      ) as GroupPinDesignCatalogDto;
    }
    return null;
  }
}
