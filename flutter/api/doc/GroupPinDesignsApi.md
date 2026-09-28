# openapi.api.GroupPinDesignsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getGroupPinDesignCatalog**](GroupPinDesignsApi.md#getgrouppindesigncatalog) | **GET** /api/v2/groups/{groupId}/pin-designs | Get the pin designs available for a group
[**updateGroupPinDesignCatalog**](GroupPinDesignsApi.md#updategrouppindesigncatalog) | **PUT** /api/v2/groups/{groupId}/pin-designs | Update a group's earned pin design


# **getGroupPinDesignCatalog**
> GroupPinDesignCatalogDto getGroupPinDesignCatalog(groupId)

Get the pin designs available for a group

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupPinDesignsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final result = api_instance.getGroupPinDesignCatalog(groupId);
    print(result);
} catch (e) {
    print('Exception when calling GroupPinDesignsApi->getGroupPinDesignCatalog: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  |

### Return type

[**GroupPinDesignCatalogDto**](GroupPinDesignCatalogDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateGroupPinDesignCatalog**
> GroupPinDesignCatalogDto updateGroupPinDesignCatalog(groupId, updateGroupPinDesignCatalogDto)

Update a group's earned pin design

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GroupPinDesignsApi();
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final updateGroupPinDesignCatalogDto = UpdateGroupPinDesignCatalogDto(); // UpdateGroupPinDesignCatalogDto |

try {
    final result = api_instance.updateGroupPinDesignCatalog(groupId, updateGroupPinDesignCatalogDto);
    print(result);
} catch (e) {
    print('Exception when calling GroupPinDesignsApi->updateGroupPinDesignCatalog: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **groupId** | **String**|  |
 **updateGroupPinDesignCatalogDto** | [**UpdateGroupPinDesignCatalogDto**](UpdateGroupPinDesignCatalogDto.md)|  |

### Return type

[**GroupPinDesignCatalogDto**](GroupPinDesignCatalogDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
