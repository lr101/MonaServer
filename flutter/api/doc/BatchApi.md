# openapi.api.BatchApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**batchRead**](BatchApi.md#batchread) | **POST** /api/v3/batch | Read several authenticated resources in one request


# **batchRead**
> BatchReadResponse batchRead(batchReadRequest)

Read several authenticated resources in one request

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = BatchApi();
final batchReadRequest = BatchReadRequest(); // BatchReadRequest | 

try {
    final result = api_instance.batchRead(batchReadRequest);
    print(result);
} catch (e) {
    print('Exception when calling BatchApi->batchRead: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **batchReadRequest** | [**BatchReadRequest**](BatchReadRequest.md)|  | 

### Return type

[**BatchReadResponse**](BatchReadResponse.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

