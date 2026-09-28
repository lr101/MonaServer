# openapi.api.SessionAuthApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**revokeOwnSession**](SessionAuthApi.md#revokeownsession) | **POST** /api/v3/auth/session/revoke | Revoke the caller's submitted refresh credential


# **revokeOwnSession**
> revokeOwnSession(sessionRevokeRequestDto)

Revoke the caller's submitted refresh credential

Revoke only the submitted refresh credential when it belongs to the bearer-authenticated caller.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SessionAuthApi();
final sessionRevokeRequestDto = SessionRevokeRequestDto(); // SessionRevokeRequestDto | 

try {
    api_instance.revokeOwnSession(sessionRevokeRequestDto);
} catch (e) {
    print('Exception when calling SessionAuthApi->revokeOwnSession: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionRevokeRequestDto** | [**SessionRevokeRequestDto**](SessionRevokeRequestDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

