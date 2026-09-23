//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PublicAuthApi {
  PublicAuthApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Complete restricted account recovery
  ///
  /// Complete restricted password recovery with a purpose-limited action token.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [RecoveryCompleteRequestDto] recoveryCompleteRequestDto (required):
  Future<Response> completeRecoveryWithHttpInfo(RecoveryCompleteRequestDto recoveryCompleteRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/public/auth/recovery/complete';

    // ignore: prefer_final_locals
    Object? postBody = recoveryCompleteRequestDto;

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

  /// Complete restricted account recovery
  ///
  /// Complete restricted password recovery with a purpose-limited action token.
  ///
  /// Parameters:
  ///
  /// * [RecoveryCompleteRequestDto] recoveryCompleteRequestDto (required):
  Future<void> completeRecovery(RecoveryCompleteRequestDto recoveryCompleteRequestDto,) async {
    final response = await completeRecoveryWithHttpInfo(recoveryCompleteRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Exchange a one-time email sign-in link
  ///
  /// Exchange an opaque link only through POST; opening or scanning a link does not consume it.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [EmailLinkExchangeRequestDto] emailLinkExchangeRequestDto (required):
  Future<Response> exchangeEmailLinkWithHttpInfo(EmailLinkExchangeRequestDto emailLinkExchangeRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/public/auth/email-link/exchange';

    // ignore: prefer_final_locals
    Object? postBody = emailLinkExchangeRequestDto;

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

  /// Exchange a one-time email sign-in link
  ///
  /// Exchange an opaque link only through POST; opening or scanning a link does not consume it.
  ///
  /// Parameters:
  ///
  /// * [EmailLinkExchangeRequestDto] emailLinkExchangeRequestDto (required):
  Future<EmailLinkExchangeResponseDto?> exchangeEmailLink(EmailLinkExchangeRequestDto emailLinkExchangeRequestDto,) async {
    final response = await exchangeEmailLinkWithHttpInfo(emailLinkExchangeRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'EmailLinkExchangeResponseDto',) as EmailLinkExchangeResponseDto;
    
    }
    return null;
  }

  /// Request a one-time email sign-in link
  ///
  /// Always returns the same accepted response for eligible and ineligible addresses.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [EmailLinkRequestDto] emailLinkRequestDto (required):
  Future<Response> requestEmailLinkWithHttpInfo(EmailLinkRequestDto emailLinkRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/api/v3/public/auth/email-link/request';

    // ignore: prefer_final_locals
    Object? postBody = emailLinkRequestDto;

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

  /// Request a one-time email sign-in link
  ///
  /// Always returns the same accepted response for eligible and ineligible addresses.
  ///
  /// Parameters:
  ///
  /// * [EmailLinkRequestDto] emailLinkRequestDto (required):
  Future<EmailLinkRequestAcceptedDto?> requestEmailLink(EmailLinkRequestDto emailLinkRequestDto,) async {
    final response = await requestEmailLinkWithHttpInfo(emailLinkRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'EmailLinkRequestAcceptedDto',) as EmailLinkRequestAcceptedDto;
    
    }
    return null;
  }
}
