# openapi.model.PinPhotoRequestDto

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**image** | **String** | Base64-encoded JPEG or PNG image. |
**idempotencyKey** | **String** | Unique request ID reused when retrying this upload. |
**latitude** | **num** |  |
**longitude** | **num** |  |
**accuracyMeters** | **num** | Reported horizontal location accuracy; updates require 50 m or better. |
**caption** | **String** |  | [optional]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
