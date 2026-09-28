# openapi.model.AdminAudiencePreviewResponseDto

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**action** | [**AdminAction**](AdminAction.md) |  | [optional]
**actorUserId** | **String** |  | [optional]
**counts** | [**AdminAudienceCountsDto**](AdminAudienceCountsDto.md) |  | [optional]
**expiresAt** | [**DateTime**](DateTime.md) |  | [optional]
**exclusions** | [**List<AdminAudienceExclusionDto>**](AdminAudienceExclusionDto.md) |  | [optional] [default to const []]
**jobId** | **String** |  | [optional]
**payloadHash** | **String** |  | [optional]
**resource** | [**AudienceResourceKind**](AudienceResourceKind.md) |  | [optional]
**snapshotId** | **String** |  |
**status** | **String** |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
