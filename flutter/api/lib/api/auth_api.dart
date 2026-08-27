//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AuthApi {
  AuthApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// User registration
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [UserRequestDto] userRequestDto (required):
  Future<Response> createUserWithHttpInfo(UserRequestDto userRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/public/signup';

    // ignore: prefer_final_locals
    Object? postBody = userRequestDto;

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

  /// User registration
  ///
  /// Parameters:
  ///
  /// * [UserRequestDto] userRequestDto (required):
  Future<TokenResponseDto?> createUser(UserRequestDto userRequestDto,) async {
    final response = await createUserWithHttpInfo(userRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenResponseDto',) as TokenResponseDto;
    
    }
    return null;
  }

  /// Generate delete code
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] username (required):
  ///   userId
  Future<Response> generateDeleteCodeWithHttpInfo(String username,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/public/delete-code/{username}'
      .replaceAll('{username}', username);

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

  /// Generate delete code
  ///
  /// Parameters:
  ///
  /// * [String] username (required):
  ///   userId
  Future<void> generateDeleteCode(String username,) async {
    final response = await generateDeleteCodeWithHttpInfo(username,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Gets the status of the server and user specific information
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getStatusWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/status';

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

  /// Gets the status of the server and user specific information
  Future<Status?> getStatus() async {
    final response = await getStatusWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'Status',) as Status;
    
    }
    return null;
  }

  /// Request a new access token
  ///
  /// Request a new access token with a refresh token
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [RefreshTokenRequestDto] refreshTokenRequestDto:
  Future<Response> refreshTokenWithHttpInfo({ RefreshTokenRequestDto? refreshTokenRequestDto, }) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/public/refresh';

    // ignore: prefer_final_locals
    Object? postBody = refreshTokenRequestDto;

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

  /// Request a new access token
  ///
  /// Request a new access token with a refresh token
  ///
  /// Parameters:
  ///
  /// * [RefreshTokenRequestDto] refreshTokenRequestDto:
  Future<TokenResponseDto?> refreshToken({ RefreshTokenRequestDto? refreshTokenRequestDto, }) async {
    final response = await refreshTokenWithHttpInfo( refreshTokenRequestDto: refreshTokenRequestDto, );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenResponseDto',) as TokenResponseDto;
    
    }
    return null;
  }

  /// Request password recovery
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] username (required):
  Future<Response> requestPasswordRecoveryWithHttpInfo(String username,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/public/recover';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'username', username));

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

  /// Request password recovery
  ///
  /// Parameters:
  ///
  /// * [String] username (required):
  Future<void> requestPasswordRecovery(String username,) async {
    final response = await requestPasswordRecoveryWithHttpInfo(username,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// User login
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [UserLoginRequest] userLoginRequest (required):
  Future<Response> userLoginWithHttpInfo(UserLoginRequest userLoginRequest,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v2/public/login';

    // ignore: prefer_final_locals
    Object? postBody = userLoginRequest;

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

  /// User login
  ///
  /// Parameters:
  ///
  /// * [UserLoginRequest] userLoginRequest (required):
  Future<TokenResponseDto?> userLogin(UserLoginRequest userLoginRequest,) async {
    final response = await userLoginWithHttpInfo(userLoginRequest,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'TokenResponseDto',) as TokenResponseDto;
    
    }
    return null;
  }
}
