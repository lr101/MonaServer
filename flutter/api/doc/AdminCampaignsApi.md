# openapi.api.AdminCampaignsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveAdminCampaign**](AdminCampaignsApi.md#archiveadmincampaign) | **POST** /api/v3/admin/campaigns/{campaignId}/archive | Archive a campaign
[**createAdminCampaign**](AdminCampaignsApi.md#createadmincampaign) | **POST** /api/v3/admin/campaigns | Create a content-only campaign
[**deleteAdminCampaign**](AdminCampaignsApi.md#deleteadmincampaign) | **DELETE** /api/v3/admin/campaigns/{campaignId} | Delete a draft campaign
[**getAdminCampaign**](AdminCampaignsApi.md#getadmincampaign) | **GET** /api/v3/admin/campaigns/{campaignId} | Get a content-only campaign
[**listAdminCampaigns**](AdminCampaignsApi.md#listadmincampaigns) | **GET** /api/v3/admin/campaigns | List content-only campaigns
[**updateAdminCampaign**](AdminCampaignsApi.md#updateadmincampaign) | **PATCH** /api/v3/admin/campaigns/{campaignId} | Update a content-only campaign


# **archiveAdminCampaign**
> AdminCampaignDto archiveAdminCampaign(campaignId, xCSRFToken, adminCampaignRevisionRequestDto)

Archive a campaign

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final campaignId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable campaign identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminCampaignRevisionRequestDto = AdminCampaignRevisionRequestDto(); // AdminCampaignRevisionRequestDto |

try {
    final result = api_instance.archiveAdminCampaign(campaignId, xCSRFToken, adminCampaignRevisionRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->archiveAdminCampaign: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **campaignId** | **String**| Stable campaign identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminCampaignRevisionRequestDto** | [**AdminCampaignRevisionRequestDto**](AdminCampaignRevisionRequestDto.md)|  |

### Return type

[**AdminCampaignDto**](AdminCampaignDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAdminCampaign**
> AdminCampaignDto createAdminCampaign(xCSRFToken, adminCampaignCreateRequestDto)

Create a content-only campaign

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminCampaignCreateRequestDto = AdminCampaignCreateRequestDto(); // AdminCampaignCreateRequestDto |

try {
    final result = api_instance.createAdminCampaign(xCSRFToken, adminCampaignCreateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->createAdminCampaign: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminCampaignCreateRequestDto** | [**AdminCampaignCreateRequestDto**](AdminCampaignCreateRequestDto.md)|  |

### Return type

[**AdminCampaignDto**](AdminCampaignDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteAdminCampaign**
> deleteAdminCampaign(campaignId, xCSRFToken, adminCampaignRevisionRequestDto)

Delete a draft campaign

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final campaignId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable campaign identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminCampaignRevisionRequestDto = AdminCampaignRevisionRequestDto(); // AdminCampaignRevisionRequestDto |

try {
    api_instance.deleteAdminCampaign(campaignId, xCSRFToken, adminCampaignRevisionRequestDto);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->deleteAdminCampaign: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **campaignId** | **String**| Stable campaign identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminCampaignRevisionRequestDto** | [**AdminCampaignRevisionRequestDto**](AdminCampaignRevisionRequestDto.md)|  |

### Return type

void (empty response body)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAdminCampaign**
> AdminCampaignDto getAdminCampaign(campaignId)

Get a content-only campaign

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final campaignId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable campaign identifier.

try {
    final result = api_instance.getAdminCampaign(campaignId);
    print(result);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->getAdminCampaign: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **campaignId** | **String**| Stable campaign identifier. |

### Return type

[**AdminCampaignDto**](AdminCampaignDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAdminCampaigns**
> AdminCampaignPageDto listAdminCampaigns(cursor, limit)

List content-only campaigns

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final cursor = cursor_example; // String | Opaque cursor returned by the preceding page.
final limit = 56; // int | Maximum number of records in the page; defaults to 25 and is capped at 100.

try {
    final result = api_instance.listAdminCampaigns(cursor, limit);
    print(result);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->listAdminCampaigns: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque cursor returned by the preceding page. | [optional]
 **limit** | **int**| Maximum number of records in the page; defaults to 25 and is capped at 100. | [optional] [default to 25]

### Return type

[**AdminCampaignPageDto**](AdminCampaignPageDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateAdminCampaign**
> AdminCampaignDto updateAdminCampaign(campaignId, xCSRFToken, adminCampaignUpdateRequestDto)

Update a content-only campaign

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure API key authorization: adminSession
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKey = 'YOUR_API_KEY';
// uncomment below to setup prefix (e.g. Bearer) for API key, if needed
//defaultApiClient.getAuthentication<ApiKeyAuth>('adminSession').apiKeyPrefix = 'Bearer';

final api_instance = AdminCampaignsApi();
final campaignId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable campaign identifier.
final xCSRFToken = xCSRFToken_example; // String | Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication.
final adminCampaignUpdateRequestDto = AdminCampaignUpdateRequestDto(); // AdminCampaignUpdateRequestDto |

try {
    final result = api_instance.updateAdminCampaign(campaignId, xCSRFToken, adminCampaignUpdateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling AdminCampaignsApi->updateAdminCampaign: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **campaignId** | **String**| Stable campaign identifier. |
 **xCSRFToken** | **String**| Double-submit CSRF value issued by the admin session bootstrap and rotated after MFA or reauthentication. |
 **adminCampaignUpdateRequestDto** | [**AdminCampaignUpdateRequestDto**](AdminCampaignUpdateRequestDto.md)|  |

### Return type

[**AdminCampaignDto**](AdminCampaignDto.md)

### Authorization

[adminSession](../README.md#adminSession)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
