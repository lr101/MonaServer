# openapi.api.AdminSessionApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**adminSessionLogin**](AdminSessionApi.md#adminsessionlogin) | **POST** /api/v3/admin/session/login | Begin an admin password and MFA login
[**bootstrapAdminSession**](AdminSessionApi.md#bootstrapadminsession) | **POST** /api/v3/admin/session/bootstrap | Bootstrap an admin browser session
[**completeAdminSessionMfa**](AdminSessionApi.md#completeadminsessionmfa) | **POST** /api/v3/admin/session/mfa | Complete admin MFA
[**getAdminSession**](AdminSessionApi.md#getadminsession) | **GET** /api/v3/admin/session | Restore the current admin session
[**logoutAdminSession**](AdminSessionApi.md#logoutadminsession) | **POST** /api/v3/admin/session/logout | Log out of the admin session
[**reauthenticateAdminSession**](AdminSessionApi.md#reauthenticateadminsession) | **POST** /api/v3/admin/session/reauthenticate | Reauthenticate an admin session for a sensitive action


# **adminSessionLogin**
> AdminSessionLoginResponseDto adminSessionLogin(xCSRFToken, adminSessionLoginRequestDto)

Begin an admin password and MFA login

Start the password challenge; this endpoint never issues a consumer JWT or refresh token.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminSessionApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminSessionLoginRequestDto = AdminSessionLoginRequestDto(); // AdminSessionLoginRequestDto |

try {
    final result = api_instance.adminSessionLogin(xCSRFToken, adminSessionLoginRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminSessionApi->adminSessionLogin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminSessionLoginRequestDto** | [**AdminSessionLoginRequestDto**](AdminSessionLoginRequestDto.md)|  |

### Return type

[**AdminSessionLoginResponseDto**](AdminSessionLoginResponseDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **bootstrapAdminSession**
> AdminSessionBootstrapDto bootstrapAdminSession()

Bootstrap an admin browser session

Create or refresh a pre-authentication browser session and issue a CSRF token bound to its challenge.

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = AdminSessionApi();

try {
    final result = api_instance.bootstrapAdminSession();
    print(result);
} catch (e) {
    print('Exception when calling AdminSessionApi->bootstrapAdminSession: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AdminSessionBootstrapDto**](AdminSessionBootstrapDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **completeAdminSessionMfa**
> AdminSessionDto completeAdminSessionMfa(xCSRFToken, adminMfaRequestDto)

Complete admin MFA

Complete the one-use MFA challenge and rotate the CSRF token on authentication.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminSessionApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminMfaRequestDto = AdminMfaRequestDto(); // AdminMfaRequestDto |

try {
    final result = api_instance.completeAdminSessionMfa(xCSRFToken, adminMfaRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminSessionApi->completeAdminSessionMfa: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminMfaRequestDto** | [**AdminMfaRequestDto**](AdminMfaRequestDto.md)|  |

### Return type

[**AdminSessionDto**](AdminSessionDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminSession**
> AdminSessionDto getAdminSession()

Restore the current admin session

Restore the current admin session and capabilities after a page reload.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminSessionApi();

try {
    final result = api_instance.getAdminSession();
    print(result);
} catch (e) {
    print('Exception when calling AdminSessionApi->getAdminSession: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AdminSessionDto**](AdminSessionDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **logoutAdminSession**
> logoutAdminSession(xCSRFToken)

Log out of the admin session

Revoke the opaque admin session and clear its browser cookie.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminSessionApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.

try {
    api_instance.logoutAdminSession(xCSRFToken);
} catch (e) {
    print('Exception when calling AdminSessionApi->logoutAdminSession: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |

### Return type

void (empty response body)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reauthenticateAdminSession**
> AdminSessionDto reauthenticateAdminSession(xCSRFToken, adminReauthenticateRequestDto)

Reauthenticate an admin session for a sensitive action

Refresh recent MFA freshness for a specific action and rotate the CSRF token.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminSessionApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminReauthenticateRequestDto = AdminReauthenticateRequestDto(); // AdminReauthenticateRequestDto |

try {
    final result = api_instance.reauthenticateAdminSession(xCSRFToken, adminReauthenticateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminSessionApi->reauthenticateAdminSession: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminReauthenticateRequestDto** | [**AdminReauthenticateRequestDto**](AdminReauthenticateRequestDto.md)|  |

### Return type

[**AdminSessionDto**](AdminSessionDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
