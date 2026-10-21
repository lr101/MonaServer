# openapi.api.GalleryApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://stick-it.lr-projects.de*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getGalleryPhotos**](GalleryApi.md#getgalleryphotos) | **GET** /api/v2/gallery/photos | Discover visible original and update photos in stable observedAt/id descending order
[**resolvePhotos**](GalleryApi.md#resolvephotos) | **POST** /api/v2/photos/resolve | Resolve signed URLs for up to 100 photos with per-item authorization


# **getGalleryPhotos**
> GalleryPhotoPageDto getGalleryPhotos(userId, groupId, cursor, limit)

Discover visible original and update photos in stable observedAt/id descending order

Exactly one of userId or groupId is required. User scope selects the contributor of each photograph. Cursor is opaque; use nextCursor until absent. Deleted pins and groups and inaccessible groups are excluded.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GalleryApi();
final userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final groupId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final cursor = cursor_example; // String |
final limit = 56; // int |

try {
    final result = api_instance.getGalleryPhotos(userId, groupId, cursor, limit);
    print(result);
} catch (e) {
    print('Exception when calling GalleryApi->getGalleryPhotos: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | [optional]
 **groupId** | **String**|  | [optional]
 **cursor** | **String**|  | [optional]
 **limit** | **int**|  | [optional] [default to 100]

### Return type

[**GalleryPhotoPageDto**](GalleryPhotoPageDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resolvePhotos**
> PhotoResolveResponseDto resolvePhotos(photoResolveRequestDto)

Resolve signed URLs for up to 100 photos with per-item authorization

Items preserve request order. An inaccessible or missing photograph returns status 404 without metadata. Each successful item contains both URL variants.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: token
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('token').setAccessToken(yourTokenGeneratorFunction);

final api_instance = GalleryApi();
final photoResolveRequestDto = PhotoResolveRequestDto(); // PhotoResolveRequestDto |

try {
    final result = api_instance.resolvePhotos(photoResolveRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling GalleryApi->resolvePhotos: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **photoResolveRequestDto** | [**PhotoResolveRequestDto**](PhotoResolveRequestDto.md)|  |

### Return type

[**PhotoResolveResponseDto**](PhotoResolveResponseDto.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
