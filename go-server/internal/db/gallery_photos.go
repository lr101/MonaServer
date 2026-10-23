package db

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
	"time"
)

type GalleryPhoto struct {
	Pin   Pin
	Photo PinPhoto
}
type GalleryPhotoSearch struct {
	CallerID               uuid.UUID
	GroupID, ContributorID *uuid.UUID
	PhotoIDs               []uuid.UUID
	BeforeDate             *time.Time
	BeforeID               *uuid.UUID
	Limit                  int32
}

func (q *Queries) GalleryPhotos(ctx context.Context, in GalleryPhotoSearch) ([]GalleryPhoto, error) {
	ids := make([]pgtype.UUID, len(in.PhotoIDs))
	for i, id := range in.PhotoIDs {
		ids[i] = pgUUID(id)
	}
	rows, err := q.g.GalleryPhotos(ctx, dbgen.GalleryPhotosParams{CallerID: pgUUID(in.CallerID), GroupID: pgUUIDPtr(in.GroupID), ContributorID: pgUUIDPtr(in.ContributorID), PhotoIds: ids, BeforeDate: pgTZ(in.BeforeDate), BeforeID: pgUUIDPtr(in.BeforeID), Lim: in.Limit})
	if err != nil {
		return nil, err
	}
	out := make([]GalleryPhoto, 0, len(rows))
	for _, row := range rows {
		p := row.Pin
		ph := row.PinPhoto
		out = append(out, GalleryPhoto{Pin: Pin{ID: goUUID(p.ID), Latitude: p.Latitude.Float64, Longitude: p.Longitude.Float64, CreationDate: goTZ(p.CreationDate), UpdateDate: goTZ(p.UpdateDate), Title: goText(p.Title), Description: goText(p.Description), CreatorID: goUUID(p.CreatorID), GroupID: goUUID(p.GroupID), IsGone: p.IsGone, ImageBlurhash: goText(p.ImageBlurhash)}, Photo: PinPhoto{ID: goUUID(ph.ID), PinID: goUUID(ph.PinID), ContributorID: goUUIDPtr(ph.ContributorID), ContributorUsername: ph.ContributorUsername, ImageKey: ph.ImageKey, Caption: goText(ph.Caption), ObservedAt: ph.ObservedAt.Time, IsOriginal: ph.IsOriginal, ImageBlurhash: goText(ph.ImageBlurhash)}})
	}
	return out, nil
}
