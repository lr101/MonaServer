package service

type XPProgress struct {
	Level        int32
	CurrentLevel int32
	NextLevel    int32
}

var levelThresholds = [...]int32{0, 25, 100, 1000, 5000, 10000}

func ProgressForXP(total int64) XPProgress {
	levelIndex := 0
	for i := 1; i < len(levelThresholds); i++ {
		if total < int64(levelThresholds[i]) {
			break
		}
		levelIndex = i
	}
	nextIndex := levelIndex + 1
	if nextIndex >= len(levelThresholds) {
		nextIndex = len(levelThresholds) - 1
	}
	return XPProgress{
		Level:        int32(levelIndex + 1),
		CurrentLevel: levelThresholds[levelIndex],
		NextLevel:    levelThresholds[nextIndex],
	}
}
