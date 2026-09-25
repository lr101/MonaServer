package service

import "testing"

func TestProgressForXPCustomLevelLadder(t *testing.T) {
	tests := []struct {
		name    string
		xp      int64
		level   int32
		current int32
		next    int32
	}{
		{name: "new player", xp: 0, level: 1, current: 0, next: 25},
		{name: "before level two", xp: 24, level: 1, current: 0, next: 25},
		{name: "level two threshold", xp: 25, level: 2, current: 25, next: 75},
		{name: "level three threshold", xp: 75, level: 3, current: 75, next: 150},
		{name: "level ten threshold", xp: 2250, level: 10, current: 2250, next: 3250},
		{name: "level fourteen threshold", xp: 10000, level: 14, current: 10000, next: 14000},
		{name: "maximum level", xp: 14000, level: 15, current: 14000, next: 14000},
		{name: "xp beyond maximum", xp: 50000, level: 15, current: 14000, next: 14000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ProgressForXP(tt.xp)
			if got.Level != tt.level || got.CurrentLevel != tt.current || got.NextLevel != tt.next {
				t.Fatalf("ProgressForXP(%d) = %+v, want level=%d current=%d next=%d", tt.xp, got, tt.level, tt.current, tt.next)
			}
		})
	}
}

func TestProgressForXPMatchesEveryLevelThreshold(t *testing.T) {
	thresholds := []struct {
		xp    int64
		level int32
	}{
		{0, 1},
		{25, 2},
		{75, 3},
		{150, 4},
		{275, 5},
		{450, 6},
		{700, 7},
		{1050, 8},
		{1550, 9},
		{2250, 10},
		{3250, 11},
		{4750, 12},
		{7000, 13},
		{10000, 14},
		{14000, 15},
	}

	for _, threshold := range thresholds {
		got := ProgressForXP(threshold.xp)
		if got.Level != threshold.level {
			t.Errorf("ProgressForXP(%d).Level = %d, want %d", threshold.xp, got.Level, threshold.level)
		}
	}
}

func TestProgressForGroupXPUsesGroupLevelLadder(t *testing.T) {
	tests := []struct {
		name    string
		xp      int64
		level   int32
		current int32
		next    int32
	}{
		{name: "new group", xp: 0, level: 1, current: 0, next: 50},
		{name: "before level two", xp: 49, level: 1, current: 0, next: 50},
		{name: "level two threshold", xp: 50, level: 2, current: 50, next: 150},
		{name: "level three threshold", xp: 150, level: 3, current: 150, next: 300},
		{name: "maximum level", xp: 28000, level: 15, current: 28000, next: 28000},
		{name: "xp beyond maximum", xp: 50000, level: 15, current: 28000, next: 28000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ProgressForGroupXP(tt.xp)
			if got.Level != tt.level || got.CurrentLevel != tt.current || got.NextLevel != tt.next {
				t.Fatalf("ProgressForGroupXP(%d) = %+v, want level=%d current=%d next=%d", tt.xp, got, tt.level, tt.current, tt.next)
			}
		})
	}
}
