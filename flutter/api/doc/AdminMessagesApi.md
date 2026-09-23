# openapi.api.AdminMessagesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**sendAdminTestMessage**](AdminMessagesApi.md#sendadmintestmessage) | **POST** /api/v3/admin/messages/test | Send an administrative test message


# **sendAdminTestMessage**
> AdminTestMessageAcceptedDto sendAdminTestMessage(xCSRFToken, adminTestMessageRequestDto)

Send an administrative test message

Validate a message and deliver only to the explicit test recipient; action tokens are never returned.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminMessagesApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminTestMessageRequestDto = AdminTestMessageRequestDto(); // AdminTestMessageRequestDto | 

try {
    final result = api_instance.sendAdminTestMessage(xCSRFToken, adminTestMessageRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminMessagesApi->sendAdminTestMessage: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. | 
 **adminTestMessageRequestDto** | [**AdminTestMessageRequestDto**](AdminTestMessageRequestDto.md)|  | 

### Return type

[**AdminTestMessageAcceptedDto**](AdminTestMessageAcceptedDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

