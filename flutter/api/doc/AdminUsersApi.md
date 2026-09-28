# openapi.api.AdminUsersApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAdminUser**](AdminUsersApi.md#getadminuser) | **GET** /api/v3/admin/users/{userId} | Get one administrative user record
[**listAdminUsers**](AdminUsersApi.md#listadminusers) | **GET** /api/v3/admin/users | Search administrative user records
[**sendAdminUserLoginLink**](AdminUsersApi.md#sendadminuserloginlink) | **POST** /api/v3/admin/users/{userId}/login-link | Queue a one-time login link to one user's verified email
[**sendAdminUserPasswordResetLink**](AdminUsersApi.md#sendadminuserpasswordresetlink) | **POST** /api/v3/admin/users/{userId}/password-reset | Send one user's password recovery email as an administrator
[**verifyAdminUserEmail**](AdminUsersApi.md#verifyadminuseremail) | **POST** /api/v3/admin/users/{userId}/verify-email | Verify one user email as an administrator


# **getAdminUser**
> AdminUserDetailsDto getAdminUser(userId)

Get one administrative user record

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable account identifier.

try {
    final result = api_instance.getAdminUser(userId);
    print(result);
} catch (e) {
    print('Exception when calling AdminUsersApi->getAdminUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**| Stable account identifier. |

### Return type

[**AdminUserDetailsDto**](AdminUserDetailsDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminUsers**
> AdminUserPageDto listAdminUsers(cursor, limit, search, securityStatus, verifiedEmail, createdAfter, createdBefore)

Search administrative user records

Return bounded account records without tokens, password hashes, or other credential material.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.
final search = search_example; // String | Case-insensitive username, email, or stable ID search.
final securityStatus = ; // AdminSecurityState | Restrict results to one security state.
final verifiedEmail = true; // bool | Restrict results by verified-email presence.
final createdAfter = 2013-10-20T19:20:30+01:00; // DateTime | Include accounts created at or after this instant.
final createdBefore = 2013-10-20T19:20:30+01:00; // DateTime | Include accounts created before this instant.

try {
    final result = api_instance.listAdminUsers(cursor, limit, search, securityStatus, verifiedEmail, createdAfter, createdBefore);
    print(result);
} catch (e) {
    print('Exception when calling AdminUsersApi->listAdminUsers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional]
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]
 **search** | **String**| Case-insensitive username, email, or stable ID search. | [optional]
 **securityStatus** | [**AdminSecurityState**](.md)| Restrict results to one security state. | [optional]
 **verifiedEmail** | **bool**| Restrict results by verified-email presence. | [optional]
 **createdAfter** | **DateTime**| Include accounts created at or after this instant. | [optional]
 **createdBefore** | **DateTime**| Include accounts created before this instant. | [optional]

### Return type

[**AdminUserPageDto**](AdminUserPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **sendAdminUserLoginLink**
> sendAdminUserLoginLink(userId, xCSRFToken, adminLoginLinkCampaignRequestDto)

Queue a one-time login link to one user's verified email

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable account identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminLoginLinkCampaignRequestDto = AdminLoginLinkCampaignRequestDto(); // AdminLoginLinkCampaignRequestDto | Optional campaign send context. Omit it to use the standard single-user sign-in message. Campaign content is loaded from the active campaign on the server.

try {
    api_instance.sendAdminUserLoginLink(userId, xCSRFToken, adminLoginLinkCampaignRequestDto);
} catch (e) {
    print('Exception when calling AdminUsersApi->sendAdminUserLoginLink: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**| Stable account identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminLoginLinkCampaignRequestDto** | [**AdminLoginLinkCampaignRequestDto**](AdminLoginLinkCampaignRequestDto.md)| Optional campaign send context. Omit it to use the standard single-user sign-in message. Campaign content is loaded from the active campaign on the server. | [optional]

### Return type

void (empty response body)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **sendAdminUserPasswordResetLink**
> sendAdminUserPasswordResetLink(userId, xCSRFToken)

Send one user's password recovery email as an administrator

Send a password recovery email to one user's verified email. The user's current password remains active until they complete recovery. Requires recent MFA bound to security.recovery_resend.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable account identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.

try {
    api_instance.sendAdminUserPasswordResetLink(userId, xCSRFToken);
} catch (e) {
    print('Exception when calling AdminUsersApi->sendAdminUserPasswordResetLink: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**| Stable account identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |

### Return type

void (empty response body)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **verifyAdminUserEmail**
> AdminUserDetailsDto verifyAdminUserEmail(userId, xCSRFToken)

Verify one user email as an administrator

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminUsersApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable account identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.

try {
    final result = api_instance.verifyAdminUserEmail(userId, xCSRFToken);
    print(result);
} catch (e) {
    print('Exception when calling AdminUsersApi->verifyAdminUserEmail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**| Stable account identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |

### Return type

[**AdminUserDetailsDto**](AdminUserDetailsDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
