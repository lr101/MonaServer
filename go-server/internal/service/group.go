package service

import (
	"context"
	"crypto/rand"
	"encoding/base32"
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
	obj  *Object
	user *User
}

func NewGroup(q *db.Queries, obj *Object, user *User) *Group {
	return &Group{q: q, obj: obj, user: user}
}

// GroupDTO is the shape returned by group endpoints.
type GroupDTO struct {
	ID           uuid.UUID   `json:"id"`
	Name         string      `json:"name"`
	Description  *string     `json:"description,omitempty"`
	Link         *string     `json:"link,omitempty"`
	Visibility   int         `json:"visibility"`
	AdminID      uuid.UUID   `json:"groupAdmin"`
	InviteUrl    *string     `json:"inviteUrl,omitempty"`
	CreationDate *time.Time  `json:"creationDate,omitempty"`
	UpdateDate   *time.Time  `json:"updateDate,omitempty"`
	Members      int64       `json:"members"`
	ProfileImage *string     `json:"profileImage,omitempty"`
	ProfileSmall *string     `json:"profileImageSmall,omitempty"`
	PinImage     *string     `json:"pinImage,omitempty"`
}

func (s *Group) toDTO(ctx context.Context, g *db.Group, withImages bool) *GroupDTO {
	count, _ := s.q.CountGroupMembers(ctx, g.ID)
	out := &GroupDTO{
		ID: g.ID, Name: g.Name, Description: g.Description, Link: g.Link,
		Visibility: g.Visibility, AdminID: g.AdminID, InviteUrl: g.InviteUrl,
		CreationDate: g.CreationDate, UpdateDate: g.UpdateDate, Members: count,
	}
	if withImages && s.obj != nil {
		if u, _ := s.obj.PresignedGet(ctx, GroupProfileKey(g.ID, false)); u != "" {
			out.ProfileImage = &u
		}
		if u, _ := s.obj.PresignedGet(ctx, GroupProfileKey(g.ID, true)); u != "" {
			out.ProfileSmall = &u
		}
		if u, _ := s.obj.PresignedGet(ctx, GroupPinKey(g.ID)); u != "" {
			out.PinImage = &u
		}
	}
	return out
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
	gid := uuid.New()
	var invite *string
	if in.Visibility == 1 {
		code := randomAlpha(6)
		invite = &code
	}
	if _, err := s.q.CreateGroup(ctx, db.Group{
		ID: gid, Name: in.Name, Description: in.Description, Link: in.Link,
		Visibility: in.Visibility, AdminID: in.GroupAdmin, InviteUrl: invite,
	}); err != nil {
		return nil, err
	}
	if err := s.q.AddMember(ctx, gid, in.GroupAdmin); err != nil {
		return nil, err
	}
	if len(in.ProfileImage) > 0 && s.obj != nil {
		_ = s.writeGroupImages(ctx, gid, in.ProfileImage)
	}
	if err := s.q.AddUserXp(ctx, in.GroupAdmin, CreateGroupXP); err != nil {
		return nil, err
	}
	g, err := s.q.GetGroupByID(ctx, gid)
	if err != nil {
		return nil, err
	}
	return s.toDTO(ctx, g, true), nil
}

func (s *Group) writeGroupImages(ctx context.Context, id uuid.UUID, raw []byte) error {
	pin, err := image.ComposePin(raw)
	if err == nil {
		_ = s.obj.Put(ctx, GroupPinKey(id), pin, "image/png")
	}
	large, err := image.ResizePNG(raw, 512, 512)
	if err == nil {
		_ = s.obj.Put(ctx, GroupProfileKey(id, false), large, "image/png")
	}
	small, err := image.ResizePNG(raw, 128, 128)
	if err == nil {
		_ = s.obj.Put(ctx, GroupProfileKey(id, true), small, "image/png")
	}
	return nil
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
	return s.toDTO(ctx, g, true), nil
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
}

func (s *Group) Update(ctx context.Context, id uuid.UUID, in UpdateGroupInput) (*GroupDTO, error) {
	g, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	u := db.GroupUpdate{Name: in.Name, Description: in.Description, Link: in.Link, AdminID: in.GroupAdmin}
	if in.Visibility != nil {
		u.Visibility = in.Visibility
		if *in.Visibility == 1 {
			code := randomAlpha(6)
			u.InviteUrl = &code
		} else {
			empty := ""
			u.InviteUrl = &empty
		}
	}
	if err := s.q.UpdateGroup(ctx, id, u); err != nil {
		return nil, err
	}
	if len(in.ProfileImage) > 0 && s.obj != nil {
		_ = s.writeGroupImages(ctx, id, in.ProfileImage)
	}
	_ = g
	updated, err := s.q.GetGroupByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return s.toDTO(ctx, updated, true), nil
}

func (s *Group) Delete(ctx context.Context, id uuid.UUID) error {
	g, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	if err := s.q.SoftDeleteGroup(ctx, id); err != nil {
		return err
	}
	_ = s.q.LogDeletion(ctx, 2, id)
	if s.obj != nil {
		_ = s.obj.Remove(ctx, GroupPinKey(id))
		_ = s.obj.Remove(ctx, GroupProfileKey(id, false))
		_ = s.obj.Remove(ctx, GroupProfileKey(id, true))
	}
	_ = g
	return nil
}

// GroupsSync mirrors GroupsSyncDto.
type GroupsSync struct {
	Groups  []*GroupDTO `json:"groups"`
	Deleted []uuid.UUID `json:"deleted"`
}

// Search mirrors getGroupsByIds.
func (s *Group) Search(ctx context.Context, search *string, userID *uuid.UUID, withUser *bool, withImages bool, page int32, size int32, updatedAfter *time.Time) (*GroupsSync, error) {
	if (withUser != nil && userID == nil) || (withUser == nil && userID != nil) {
		return nil, apperrors.ErrBadRequest
	}
	groups, err := s.q.SearchGroups(ctx, db.GroupSearch{
		Search: search, UpdatedAfter: updatedAfter, UserID: userID, WithUser: withUser,
		Limit: size, Offset: page * size,
	})
	if err != nil {
		return nil, err
	}
	out := make([]*GroupDTO, 0, len(groups))
	for i := range groups {
		out = append(out, s.toDTO(ctx, &groups[i], withImages))
	}
	var deleted []uuid.UUID
	if updatedAfter != nil {
		deleted, _ = s.q.ListDeletedGroupsAfter(ctx, *updatedAfter)
	}
	return &GroupsSync{Groups: out, Deleted: deleted}, nil
}

// ProfileImageURL / PinImageURL return presigned URLs.
func (s *Group) ProfileImageURL(ctx context.Context, id uuid.UUID, small bool) (*string, error) {
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
