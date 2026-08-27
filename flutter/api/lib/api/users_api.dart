//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class UsersApi {
  UsersApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Claim an achievement
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [int] achievementId (required):
  Future<Response> claimUserAchievementWithHttpInfo(String userId, int achievementId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/achievements/{achievementId}'
      .replaceAll('{userId}', userId)
      .replaceAll('{achievementId}', achievementId.toString());

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Claim an achievement
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [int] achievementId (required):
  Future<void> claimUserAchievement(String userId, int achievementId,) async {
    final response = await claimUserAchievementWithHttpInfo(userId, achievementId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Delete a user by userId
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [int] body:
  Future<Response> deleteUserWithHttpInfo(String userId, { int? body, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

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

  /// Delete a user by userId
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [int] body:
  Future<void> deleteUser(String userId, { int? body, }) async {
    final response = await deleteUserWithHttpInfo(userId,  body: body, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Get a user by userId
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> getUserWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}'
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

  /// Get a user by userId
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<UserInfoDto?> getUser(String userId,) async {
    final response = await getUserWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'UserInfoDto',) as UserInfoDto;
    
    }
    return null;
  }

  /// Get user's achievements
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> getUserAchievementsWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/achievements'
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

  /// Get user's achievements
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<List<UserAchievementsDtoInner>?> getUserAchievements(String userId,) async {
    final response = await getUserAchievementsWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<UserAchievementsDtoInner>') as List)
        .cast<UserAchievementsDtoInner>()
        .toList(growable: false);

    }
    return null;
  }

  /// Get the profile picture of a user by userId
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getUserProfileImageWithHttpInfo(String userId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/profile_picture'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (redirect != null) {
      queryParams.addAll(_queryParams('', 'redirect', redirect));
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

  /// Get the profile picture of a user by userId
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getUserProfileImage(String userId, { bool? redirect, }) async {
    final response = await getUserProfileImageWithHttpInfo(userId,  redirect: redirect, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'String',) as String;
    
    }
    return null;
  }

  /// Get the small profile picture of a user by userId
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<Response> getUserProfileImageSmallWithHttpInfo(String userId, { bool? redirect, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/profile_picture_small'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (redirect != null) {
      queryParams.addAll(_queryParams('', 'redirect', redirect));
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

  /// Get the small profile picture of a user by userId
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [bool] redirect:
  ///   When true, this endpoint redirects directly to the target image otherwise the image URL is returned
  Future<String?> getUserProfileImageSmall(String userId, { bool? redirect, }) async {
    final response = await getUserProfileImageSmallWithHttpInfo(userId,  redirect: redirect, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'String',) as String;
    
    }
    return null;
  }

  /// Get user's xp
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<Response> getUserXpWithHttpInfo(String userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}/xp'
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

  /// Get user's xp
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  Future<UserXpDto?> getUserXp(String userId,) async {
    final response = await getUserXpWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'UserXpDto',) as UserXpDto;
    
    }
    return null;
  }

  /// Update user information by userId
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [UserUpdateDto] userUpdateDto (required):
  Future<Response> updateUserWithHttpInfo(String userId, UserUpdateDto userUpdateDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/users/{userId}'
      .replaceAll('{userId}', userId);

    // ignore: prefer_final_locals
    Object? postBody = userUpdateDto;

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

  /// Update user information by userId
  ///
  /// Parameters:
  ///
  /// * [String] userId (required):
  ///
  /// * [UserUpdateDto] userUpdateDto (required):
  Future<UserUpdateResponseDto?> updateUser(String userId, UserUpdateDto userUpdateDto,) async {
    final response = await updateUserWithHttpInfo(userId, userUpdateDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'UserUpdateResponseDto',) as UserUpdateResponseDto;
    
    }
    return null;
  }
}
