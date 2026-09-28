# openapi.model.UserAchievementsDtoInner

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**achievementId** | **int** |  |
**name** | **String** |  | [optional]
**description** | **String** |  | [optional]
**track** | **String** |  | [optional]
**difficulty** | **String** |  | [optional]
**rewardType** | **String** | Each achievement grants exactly one reward category. Easy achievements grant XP, medium achievements grant a color, and hard achievements grant a badge. | [optional]
**rewardColor** | **String** |  | [optional]
**rewardXp** | **int** | XP amount for XP rewards; omitted for color and badge rewards. | [optional]
**claimable** | **bool** |  | [optional]
**rewardAvailable** | **bool** |  | [optional]
**definitionVersion** | **int** |  | [optional]
**claimed** | **bool** |  |
**thresholdValue** | **int** |  |
**currentValue** | **int** |  |
**thresholdUp** | **bool** |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
