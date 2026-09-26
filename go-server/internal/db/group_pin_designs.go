package db

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/lrprojects/monaserver/internal/apperrors"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

type GroupPinDesign struct {
	Style            string  `json:"style"`
	Name             string  `json:"name"`
	Shape            string  `json:"shape"`
	BodyColor        string  `json:"bodyColor"`
	OutlineColor     string  `json:"outlineColor"`
	OutlineWidth     float64 `json:"outlineWidth"`
	ImageInset       float64 `json:"imageInset"`
	ImageZoom        float64 `json:"imageZoom"`
	ImageAlignmentX  float64 `json:"imageAlignmentX"`
	ImageAlignmentY  float64 `json:"imageAlignmentY"`
	ImageBorderColor string  `json:"imageBorderColor"`
	Badge            string  `json:"badge"`
	Shadow           bool    `json:"shadow"`
}

type GroupPinDesignCatalog struct {
	Revision int64            `json:"revision"`
	Designs  []GroupPinDesign `json:"designs"`
}

func DefaultGroupPinDesign(style string) GroupPinDesign {
	design := GroupPinDesign{
		Style: style, Name: "Classic", Shape: "circle", BodyColor: "#2457D6",
		OutlineColor: "#FFFFFF", OutlineWidth: 2, ImageInset: 2, ImageZoom: 1,
		ImageAlignmentX: 0, ImageAlignmentY: 0, ImageBorderColor: "#FFFFFF",
		Badge: "none", Shadow: true,
	}
	switch style {
	case "moss":
		design.Name, design.BodyColor, design.Badge = "Moss", "#668465", "leaf"
	case "sunset":
		design.Name, design.BodyColor, design.Badge = "Sunset", "#D57B50", "sun"
	case "aurora":
		design.Name, design.BodyColor, design.Badge = "Aurora", "#6D77BA", "spark"
	}
	return design
}

func (q *Queries) GetGroupPinDesignCatalog(ctx context.Context, groupID uuid.UUID) (GroupPinDesignCatalog, error) {
	row, err := q.g.GetGroupPinDesignCatalog(ctx, pgUUID(groupID))
	if errors.Is(err, pgx.ErrNoRows) {
		return GroupPinDesignCatalog{Revision: 1, Designs: []GroupPinDesign{}}, nil
	}
	if err != nil {
		return GroupPinDesignCatalog{}, err
	}
	var designs []GroupPinDesign
	if err := json.Unmarshal(row.Designs, &designs); err != nil {
		return GroupPinDesignCatalog{}, err
	}
	if designs == nil {
		designs = []GroupPinDesign{}
	}
	return GroupPinDesignCatalog{Revision: row.Revision, Designs: designs}, nil
}

func (q *Queries) UpdateGroupPinDesignCatalog(ctx context.Context, groupID uuid.UUID, expectedRevision int64, designs []GroupPinDesign) (GroupPinDesignCatalog, error) {
	encoded, err := json.Marshal(designs)
	if err != nil {
		return GroupPinDesignCatalog{}, err
	}
	row, err := q.g.UpdateGroupPinDesignCatalog(ctx, dbgen.UpdateGroupPinDesignCatalogParams{
		GroupID:          pgUUID(groupID),
		ExpectedRevision: expectedRevision,
		Designs:          encoded,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return GroupPinDesignCatalog{}, apperrors.ErrConflict
	}
	if err != nil {
		return GroupPinDesignCatalog{}, err
	}
	var updated []GroupPinDesign
	if err := json.Unmarshal(row.Designs, &updated); err != nil {
		return GroupPinDesignCatalog{}, err
	}
	if updated == nil {
		updated = []GroupPinDesign{}
	}
	return GroupPinDesignCatalog{Revision: row.Revision, Designs: updated}, nil
}
