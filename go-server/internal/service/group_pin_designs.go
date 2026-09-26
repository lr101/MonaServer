package service

import (
	"context"
	"math"
	"regexp"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

var (
	ErrInvalidGroupPinDesign     = apperrors.New(400, "invalid group pin design")
	ErrGroupPinDesignUnavailable = apperrors.New(503, "group pin design storage unavailable")
	ErrGroupPinStyleLocked       = apperrors.New(403, "group pin style is not unlocked")
)

type GroupPinDesignCatalogStore interface {
	GetGroupAchievementProgress(context.Context, uuid.UUID) ([]db.GroupAchievementProgress, error)
	IsGroupPinStyleUnlocked(context.Context, uuid.UUID, string) (bool, error)
	GetGroupPinDesignCatalog(context.Context, uuid.UUID) (db.GroupPinDesignCatalog, error)
	UpdateGroupPinDesignCatalog(context.Context, uuid.UUID, int64, []db.GroupPinDesign) (db.GroupPinDesignCatalog, error)
}

type GroupPinDesignCatalogService struct {
	store GroupPinDesignCatalogStore
}

func NewGroupPinDesignCatalogService(store GroupPinDesignCatalogStore) *GroupPinDesignCatalogService {
	return &GroupPinDesignCatalogService{store: store}
}

func (s *GroupPinDesignCatalogService) Get(ctx context.Context, groupID uuid.UUID) (db.GroupPinDesignCatalog, error) {
	if s == nil || s.store == nil {
		return db.GroupPinDesignCatalog{}, ErrGroupPinDesignUnavailable
	}
	stored, err := s.store.GetGroupPinDesignCatalog(ctx, groupID)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	progress, err := s.store.GetGroupAchievementProgress(ctx, groupID)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	return mergeGroupPinDesignCatalog(stored, progress), nil
}

func mergeGroupPinDesignCatalog(stored db.GroupPinDesignCatalog, progress []db.GroupAchievementProgress) db.GroupPinDesignCatalog {
	unlocked := map[string]bool{"classic": true}
	for _, achievement := range progress {
		if achievement.Claimed {
			unlocked[achievement.RewardPinStyle] = true
		}
	}
	overrides := make(map[string]db.GroupPinDesign, len(stored.Designs))
	for _, design := range stored.Designs {
		overrides[design.Style] = design
	}

	designs := make([]db.GroupPinDesign, 0, len(unlocked))
	for _, style := range []string{"classic", "moss", "sunset", "aurora"} {
		if !unlocked[style] {
			continue
		}
		design, ok := overrides[style]
		if !ok {
			design = db.DefaultGroupPinDesign(style)
		}
		designs = append(designs, design)
	}
	return db.GroupPinDesignCatalog{Revision: stored.Revision, Designs: designs}
}

func (s *GroupPinDesignCatalogService) Update(ctx context.Context, groupID uuid.UUID, expectedRevision int64, design db.GroupPinDesign) (db.GroupPinDesignCatalog, error) {
	if s == nil || s.store == nil {
		return db.GroupPinDesignCatalog{}, ErrGroupPinDesignUnavailable
	}
	if expectedRevision < 1 || !validGroupPinDesign(design) {
		return db.GroupPinDesignCatalog{}, ErrInvalidGroupPinDesign
	}
	if design.Style == "classic" {
		return db.GroupPinDesignCatalog{}, ErrGroupPinStyleLocked
	}
	unlocked, err := s.store.IsGroupPinStyleUnlocked(ctx, groupID, design.Style)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	if !unlocked {
		return db.GroupPinDesignCatalog{}, ErrGroupPinStyleLocked
	}
	design.Name = db.DefaultGroupPinDesign(design.Style).Name

	stored, err := s.store.GetGroupPinDesignCatalog(ctx, groupID)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	if stored.Revision != expectedRevision {
		return db.GroupPinDesignCatalog{}, apperrors.ErrConflict
	}
	designs := make([]db.GroupPinDesign, 0, len(stored.Designs)+1)
	updated := false
	for _, current := range stored.Designs {
		if current.Style == design.Style {
			designs = append(designs, design)
			updated = true
		} else {
			designs = append(designs, current)
		}
	}
	if !updated {
		designs = append(designs, design)
	}
	progress, err := s.store.GetGroupAchievementProgress(ctx, groupID)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	updatedCatalog, err := s.store.UpdateGroupPinDesignCatalog(ctx, groupID, expectedRevision, designs)
	if err != nil {
		return db.GroupPinDesignCatalog{}, err
	}
	return mergeGroupPinDesignCatalog(updatedCatalog, progress), nil
}

var groupPinHexColor = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

func validGroupPinDesign(design db.GroupPinDesign) bool {
	if !db.ValidGroupPinStyle(design.Style) {
		return false
	}
	if design.Shape != "teardrop" && design.Shape != "circle" && design.Shape != "shield" {
		return false
	}
	if !groupPinHexColor.MatchString(design.BodyColor) || !groupPinHexColor.MatchString(design.OutlineColor) || !groupPinHexColor.MatchString(design.ImageBorderColor) {
		return false
	}
	if !inRange(design.OutlineWidth, 0, 5) || !inRange(design.ImageInset, 0, 8) || !inRange(design.ImageZoom, 1, 2.5) || !inRange(design.ImageAlignmentX, -1, 1) || !inRange(design.ImageAlignmentY, -1, 1) {
		return false
	}
	switch design.Badge {
	case "none", "star", "leaf", "sun", "spark":
		return true
	default:
		return false
	}
}

func inRange(value, minimum, maximum float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value >= minimum && value <= maximum
}
