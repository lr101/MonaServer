# openapi.model.GroupAchievementsDtoInner

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
**claimed** | **bool** |  |
**claimable** | **bool** |  |
**thresholdValue** | **int** |  |
**currentValue** | **int** |  |
**thresholdUp** | **bool** |  |
**rewardType** | **String** | Each group achievement grants exactly one reward category based on its difficulty. | [optional]
**rewardColor** | **String** | Color granted by medium difficulty achievements. | [optional]
**rewardPinStyle** | **String** | Color preset for color rewards or badge design for badge rewards. | [optional]
**rewardXp** | **int** | Group XP amount for XP rewards; omitted for color and badge rewards. | [optional]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
