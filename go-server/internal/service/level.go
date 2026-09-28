package service

type XPProgress struct {
	Level        int32
	CurrentLevel int32
	NextLevel    int32
}

var levelThresholds = [...]int32{
	0, 25, 75, 150, 275, 450, 700, 1050, 1550, 2250,
	3250, 4750, 7000, 10000, 14000,
}

type AvatarLevelProgression struct {
	Level    int32
	Fraction float64
}

func AvatarProgressionForXP(total int64) AvatarLevelProgression {
	progress := ProgressForXP(total)
	return AvatarLevelProgression{
		Level:    progress.Level,
		Fraction: levelFraction(total, progress.CurrentLevel, progress.NextLevel),
	}
}

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

type GroupLevelProgress struct {
	Level        int32
	CurrentLevel int32
	NextLevel    int32
}

var groupLevelThresholds = [...]int32{
	0, 50, 150, 300, 550, 900, 1400, 2100, 3100, 4500,
	6500, 9500, 14000, 20000, 28000,
}

func ProgressForGroupXP(total int64) GroupLevelProgress {
	if total < 0 {
		total = 0
	}
	levelIndex := 0
	for i := 1; i < len(groupLevelThresholds); i++ {
		if total < int64(groupLevelThresholds[i]) {
			break
		}
		levelIndex = i
	}
	nextIndex := levelIndex + 1
	if nextIndex >= len(groupLevelThresholds) {
		nextIndex = len(groupLevelThresholds) - 1
	}
	return GroupLevelProgress{
		Level:        int32(levelIndex + 1),
		CurrentLevel: groupLevelThresholds[levelIndex],
		NextLevel:    groupLevelThresholds[nextIndex],
	}
}

func AvatarProgressionForGroupXP(total int64) AvatarLevelProgression {
	progress := ProgressForGroupXP(total)
	return AvatarLevelProgression{
		Level:    progress.Level,
		Fraction: levelFraction(total, progress.CurrentLevel, progress.NextLevel),
	}
}

func levelFraction(total int64, current, next int32) float64 {
	if next <= current {
		return 1
	}
	fraction := float64(total-int64(current)) / float64(next-current)
	if fraction < 0 {
		return 0
	}
	if fraction > 1 {
		return 1
	}
	return fraction
}
