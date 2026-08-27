# openapi.api.PublicApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getServerInfo**](PublicApi.md#getserverinfo) | **GET** /api/v2/public/infos | Get public server statistics


# **getServerInfo**
> List<InfoDto> getServerInfo()

Get public server statistics

### Example
```dart
import 'package:openapi/api.dart';

final api_instance = PublicApi();

try {
    final result = api_instance.getServerInfo();
    print(result);
} catch (e) {
    print('Exception when calling PublicApi->getServerInfo: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<InfoDto>**](InfoDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

