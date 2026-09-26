package service

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/image"
)

// XP awarded for creating a group — mirrors XpType.CREATE_GROUP_XP.
const CreateGroupXP = 10

// Group service — mirrors GroupServiceImpl.
type Group struct {
	q    *db.Queries
	obj  groupObjectStore
	user *User
}

type groupObjectStore interface {
	Put(context.Context, string, []byte, string) error
	GetIfExists(context.Context, string) ([]byte, bool, error)
	Remove(context.Context, string) error
	PresignedGet(context.Context, string) (string, error)
}

func NewGroup(q *db.Queries, obj *Object, user *User) *Group {
	group := &Group{q: q, user: user}
	if obj != nil {
		group.obj = obj
	}
	return group
}

// GroupDTO is the shape returned by group endpoints.
type GroupDTO struct {
	ID           uuid.UUID      `json:"id"`
	Name         string         `json:"name"`
	Description  *string        `json:"description,omitempty"`
	Link         *string        `json:"link,omitempty"`
	Visibility   int            `json:"visibility"`
	AdminID      uuid.UUID      `json:"groupAdmin"`
	InviteUrl    *string        `json:"inviteUrl,omitempty"`
	CreationDate *time.Time     `json:"creationDate,omitempty"`
	UpdateDate   *time.Time     `json:"updateDate,omitempty"`
	Members      int64          `json:"members"`
	ProfileImage *string        `json:"profileImage,omitempty"`
	ProfileSmall *string        `json:"profileImageSmall,omitempty"`
	PinImage     *string        `json:"pinImage,omitempty"`
	PinStyle     string         `json:"pinStyle"`
	BestSeason   *db.SeasonItem `json:"bestSeason,omitempty"`
}

type GroupProgression struct {
	GroupID        uuid.UUID
	TotalXP        int32
	CurrentLevel   int32
	CurrentLevelXP int32
	NextLevelXP    int32
	Visibility     int
}

func (s *Group) toDTO(ctx context.Context, g *db.Group, withImages bool) (*GroupDTO, error) {
	count, err := s.q.CountGroupMembers(ctx, g.ID)
	if err != nil {
		return nil, err
	}
	out := &GroupDTO{
		ID: g.ID, Name: g.Name, Description: g.Description, Link: g.Link,
		Visibility: g.Visibility, AdminID: g.AdminID, InviteUrl: g.InviteUrl,
		PinStyle:     g.PinStyle,
		CreationDate: g.CreationDate, UpdateDate: g.UpdateDate, Members: count,
	}
	out.BestSeason, err = s.q.GetBestGroupSeason(ctx, g.ID)
	if err != nil {
		return nil, err
	}
	if withImages && s.obj != nil {
		if u, err := s.obj.PresignedGet(ctx, GroupProfileKey(g.ID, false)); err == nil && u != "" {
			out.ProfileImage = &u
		}
		if u, err := s.obj.PresignedGet(ctx, GroupProfileKey(g.ID, true)); err == nil && u != "" {
			out.ProfileSmall = &u
		}
		if u, err := s.obj.PresignedGet(ctx, GroupPinKey(g.ID)); err == nil && u != "" {
			out.PinImage = &u
		}
	}
	return out, nil
}

// CreateGroupInput mirrors CreateGroupDto.
type CreateGroupInput struct {
	Name         string    `json:"name"`
	Description  *string   `json:"description,omitempty"`
	Link         *string   `json:"link,omitempty"`
	Visibility   int       `json:"visibility"`
	GroupAdmin   uuid.UUID `json:"groupAdmin"`
	ProfileImage []byte    `json:"profileImage,omitempty"`
}

func (s *Group) Create(ctx context.Context, in CreateGroupInput) (*GroupDTO, error) {
	exists, err := s.q.GroupExistsByName(ctx, in.Name)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, apperrors.ErrConflict
	}
	admin, err := s.q.GetUserByID(ctx, in.GroupAdmin)
	if err != nil {
		return nil, err
	}
	if admin == nil {
		return nil, apperrors.ErrNotFound
	}
	images, err := prepareGroupImages(in.ProfileImage)
	if err != nil {
		return nil, err
	}
	gid := uuid.New()
	var invite *string
	if in.Visibility == 1 {
		code := randomAlpha(6)
		invite = &code
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		if _, err := q.CreateGroup(ctx, db.Group{
			ID: gid, Name: in.Name, Description: in.Description, Link: in.Link,
			Visibility: in.Visibility, AdminID: in.GroupAdmin, InviteUrl: invite,
		}); err != nil {
			return err
		}
		if err := q.AddMember(ctx, gid, in.GroupAdmin); err != nil {
			return err
		}
		if err := s.storeGroupImages(ctx, gid, images); err != nil {
			return err
		}
		return q.AddUserXp(ctx, in.GroupAdmin, CreateGroupXP)
	}); err != nil {
		return nil, err
	}
	g, err := s.q.GetGroupByID(ctx, gid)
	if err != nil {
		return nil, err
	}
	return s.toDTO(ctx, g, true)
}

type preparedGroupImages struct {
	pin   []byte
	large []byte
	small []byte
}

func prepareGroupImages(raw []byte) (*preparedGroupImages, error) {
	if len(raw) == 0 {
		return nil, nil
	}
	pin, err := image.ComposePin(raw)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	large, err := image.CompressProfileJPEG(raw, 500)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	small, err := image.CompressProfileJPEG(raw, 100)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	return &preparedGroupImages{pin: pin, large: large, small: small}, nil
}

func (s *Group) storeGroupImages(ctx context.Context, id uuid.UUID, images *preparedGroupImages) error {
	if images == nil || s.obj == nil {
		return nil
	}
	writes := []groupObjectWrite{
		{key: GroupPinKey(id), data: images.pin, contentType: "image/png"},
		{key: GroupProfileKey(id, false), data: images.large, contentType: "image/jpeg"},
		{key: GroupProfileKey(id, true), data: images.small, contentType: "image/jpeg"},
	}
	backups := make([]groupObjectBackup, len(writes))
	for i, write := range writes {
		data, exists, err := s.obj.GetIfExists(ctx, write.key)
		if err != nil {
			return err
		}
		backups[i] = groupObjectBackup{data: data, exists: exists}
	}
	for i, write := range writes {
		if err := s.obj.Put(ctx, write.key, write.data, write.contentType); err != nil {
			return errors.Join(err, s.restoreGroupImages(ctx, writes[:i+1], backups[:i+1]))
		}
	}
	return nil
}

type groupObjectWrite struct {
	key         string
	data        []byte
	contentType string
}

type groupObjectBackup struct {
	data   []byte
	exists bool
}

func (s *Group) restoreGroupImages(ctx context.Context, writes []groupObjectWrite, backups []groupObjectBackup) error {
	var restoreErr error
	for i := len(writes) - 1; i >= 0; i-- {
		var err error
		if backups[i].exists {
			err = s.obj.Put(ctx, writes[i].key, backups[i].data, writes[i].contentType)
		} else {
			err = s.obj.Remove(ctx, writes[i].key)
		}
		restoreErr = errors.Join(restoreErr, err)
	}
	return restoreErr
}

func (s *Group) Get(ctx context.Context, id uuid.UUID) (*db.Group, error) {
	g, err := s.q.GetGroupByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if g == nil {
		return nil, apperrors.ErrNotFound
	}
	return g, nil
}

func (s *Group) GetDTO(ctx context.Context, id uuid.UUID) (*GroupDTO, error) {
	g, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	return s.toDTO(ctx, g, true)
}

func (s *Group) Progression(ctx context.Context, id uuid.UUID) (*GroupProgression, error) {
	g, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	totalXP, err := s.q.GetGroupXP(ctx, id)
	if err != nil {
		return nil, err
	}
	level := ProgressForGroupXP(int64(totalXP))
	return &GroupProgression{
		GroupID: id, TotalXP: totalXP, CurrentLevel: level.Level,
		CurrentLevelXP: level.CurrentLevel, NextLevelXP: level.NextLevel,
		Visibility: g.Visibility,
	}, nil
}

type GroupAvatarProgression struct {
	Progression AvatarLevelProgression
	Visible     bool
}

func (s *Group) AvatarProgressions(ctx context.Context, viewerID uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]GroupAvatarProgression, error) {
	records, err := s.q.GetGroupAvatarProgressionsByIDs(ctx, viewerID, ids)
	if err != nil {
		return nil, err
	}
	progressions := make(map[uuid.UUID]GroupAvatarProgression, len(records))
	for _, record := range records {
		progressions[record.GroupID] = GroupAvatarProgression{
			Progression: AvatarProgressionForGroupXP(record.TotalXP),
			Visible:     record.Visibility == 0 || record.IsMember,
		}
	}
	return progressions, nil
}

func (s *Group) GetAdminUsername(ctx context.Context, id uuid.UUID) (string, error) {
	return s.q.GetGroupAdminUsername(ctx, id)
}

// UpdateGroupInput mirrors UpdateGroupDto.
type UpdateGroupInput struct {
	Name         *string    `json:"name,omitempty"`
	Description  *string    `json:"description,omitempty"`
	Link         *string    `json:"link,omitempty"`
	Visibility   *int       `json:"visibility,omitempty"`
	GroupAdmin   *uuid.UUID `json:"groupAdmin,omitempty"`
	ProfileImage []byte     `json:"profileImage,omitempty"`
	PinStyle     *string    `json:"pinStyle,omitempty"`
}

func (s *Group) Update(ctx context.Context, id uuid.UUID, in UpdateGroupInput) (*GroupDTO, error) {
	_, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.GroupAdmin != nil {
		admin, err := s.q.GetUserByID(ctx, *in.GroupAdmin)
		if err != nil {
			return nil, err
		}
		if admin == nil {
			return nil, apperrors.ErrNotFound
		}
	}
	if in.PinStyle != nil {
		if !db.ValidGroupPinStyle(*in.PinStyle) {
			return nil, apperrors.ErrBadRequest
		}
		unlocked, err := s.q.IsGroupPinStyleUnlocked(ctx, id, *in.PinStyle)
		if err != nil {
			return nil, err
		}
		if !unlocked {
			return nil, apperrors.ErrForbidden
		}
	}
	images, err := prepareGroupImages(in.ProfileImage)
	if err != nil {
		return nil, err
	}
	u := db.GroupUpdate{
		Name: in.Name, Description: in.Description, Link: in.Link,
		AdminID: in.GroupAdmin, PinStyle: in.PinStyle,
	}
	if in.Visibility != nil {
		u.Visibility = in.Visibility
		if *in.Visibility == 1 {
			code := randomAlpha(6)
			u.InviteUrl = &code
		} else {
			u.ClearInviteURL = true
		}
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		if err := q.UpdateGroup(ctx, id, u); err != nil {
			return err
		}
		return s.storeGroupImages(ctx, id, images)
	}); err != nil {
		return nil, err
	}
	updated, err := s.q.GetGroupByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return s.toDTO(ctx, updated, true)
}

func (s *Group) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	var objectKeys []string
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		locked, err := q.LockGroupForDelete(ctx, id)
		if err != nil {
			return err
		}
		if !locked {
			return apperrors.ErrNotFound
		}
		pinIDs, err := q.ListGroupPinIDs(ctx, id)
		if err != nil {
			return err
		}
		objectKeys = make([]string, 0, len(pinIDs)*2+3)
		for _, pinID := range pinIDs {
			pinLocked, err := q.LockPinForDelete(ctx, pinID)
			if err != nil {
				return err
			}
			if !pinLocked {
				continue
			}
			keys, err := q.ListPinPhotoKeys(ctx, pinID)
			if err != nil {
				return err
			}
			objectKeys = append(objectKeys, PinKey(pinID))
			objectKeys = append(objectKeys, keys...)
			if err := q.LogDeletion(ctx, db.DeletedEntityPin, pinID); err != nil {
				return err
			}
		}
		objectKeys = append(objectKeys,
			GroupPinKey(id),
			GroupProfileKey(id, false),
			GroupProfileKey(id, true),
		)
		if err := q.EnqueueObjectCleanup(ctx, objectKeys); err != nil {
			return err
		}
		if err := q.LogDeletion(ctx, db.DeletedEntityGroup, id); err != nil {
			return err
		}
		return q.HardDeleteGroup(ctx, id)
	}); err != nil {
		return err
	}
	tryObjectCleanup(ctx, s.q, s.obj)
	return nil
}

// GroupsSync mirrors GroupsSyncDto.
type GroupsSync struct {
	Groups  []*GroupDTO `json:"groups"`
	Deleted []uuid.UUID `json:"deleted"`
}

// Search mirrors getGroupsByIds.
func (s *Group) Search(ctx context.Context, search *string, userID *uuid.UUID, withUser *bool, withImages bool, page int32, size int32, updatedAfter *time.Time, ids ...uuid.UUID) (*GroupsSync, error) {
	if (withUser != nil && userID == nil) || (withUser == nil && userID != nil) {
		return nil, apperrors.ErrBadRequest
	}
	groups, err := s.q.SearchGroups(ctx, db.GroupSearch{
		IDs: ids, Search: search, UpdatedAfter: updatedAfter, UserID: userID, WithUser: withUser,
		Limit: size, Offset: page * size,
	})
	if err != nil {
		return nil, err
	}
	out := make([]*GroupDTO, len(groups))
	for i := range groups {
		out[i], err = s.toDTO(ctx, &groups[i], withImages)
		if err != nil {
			return nil, err
		}
	}
	var deleted []uuid.UUID
	if updatedAfter != nil {
		deleted, err = s.q.ListDeletedGroupsAfter(ctx, *updatedAfter)
		if err != nil {
			return nil, err
		}
	}
	return &GroupsSync{Groups: out, Deleted: deleted}, nil
}

// ProfileImageURL / PinImageURL return presigned URLs.
func (s *Group) ProfileImageURL(ctx context.Context, id uuid.UUID, small bool) (*string, error) {
	if _, err := s.Get(ctx, id); err != nil {
		return nil, err
	}
	if s.obj == nil {
		return nil, nil
	}
	u, err := s.obj.PresignedGet(ctx, GroupProfileKey(id, small))
	if err != nil || u == "" {
		return nil, err
	}
	return &u, nil
}

func (s *Group) PinImageURL(ctx context.Context, id uuid.UUID) (*string, error) {
	if _, err := s.Get(ctx, id); err != nil {
		return nil, err
	}
	if s.obj == nil {
		return nil, nil
	}
	u, err := s.obj.PresignedGet(ctx, GroupPinKey(id))
	if err != nil || u == "" {
		return nil, err
	}
	return &u, nil
}

// helpers

func randomAlpha(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return strings.ToUpper(base32.StdEncoding.EncodeToString(b))[:n]
}
