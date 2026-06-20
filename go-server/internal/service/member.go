package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

// Member service — mirrors MemberServiceImpl.
type Member struct {
	q     *db.Queries
	obj   *Object
	group *Group
}

func NewMember(q *db.Queries, obj *Object, group *Group) *Member {
	return &Member{q: q, obj: obj, group: group}
}

// MemberResponse mirrors MemberResponseDto.
type MemberResponse struct {
	UserID            uuid.UUID `json:"userId"`
	Username          string    `json:"username"`
	Ranking           int32     `json:"ranking"`
	ProfileImageSmall *string   `json:"profileImageSmall,omitempty"`
	SelectedBatch     *int32    `json:"selectedBatch,omitempty"`
}

// Join adds a user to a group. Returns the group DTO on success.
// Mirrors MemberServiceImpl.addMember: requires visibility==0 or matching inviteUrl.
func (s *Member) Join(ctx context.Context, groupID, userID uuid.UUID, inviteUrl *string) (*GroupDTO, error) {
	g, err := s.q.GetGroupByID(ctx, groupID)
	if err != nil {
		return nil, err
	}
	if g == nil {
		return nil, apperrors.ErrNotFound
	}
	allow := g.Visibility == 0
	if !allow && g.InviteUrl != nil && inviteUrl != nil && *g.InviteUrl == *inviteUrl {
		allow = true
	}
	if !allow {
		return nil, apperrors.ErrBadRequest
	}
	member, err := s.q.IsMember(ctx, groupID, userID)
	if err != nil {
		return nil, err
	}
	if member {
		return nil, apperrors.ErrConflict
	}
	if _, err := s.q.GetUserByID(ctx, userID); err != nil {
		return nil, err
	}
	if err := s.q.AddMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.group.toDTO(ctx, g, true), nil
}

// Leave removes a user from a group. If the user is the admin and sole member,
// the group is deleted. Admin with other members cannot leave.
func (s *Member) Leave(ctx context.Context, groupID, userID uuid.UUID) error {
	g, err := s.q.GetGroupByID(ctx, groupID)
	if err != nil {
		return err
	}
	if g == nil {
		return apperrors.ErrNotFound
	}
	if g.AdminID == userID {
		count, err := s.q.CountGroupMembers(ctx, groupID)
		if err != nil {
			return err
		}
		if count == 1 {
			return s.group.Delete(ctx, groupID)
		}
		return apperrors.ErrConflict
	}
	return s.q.RemoveMember(ctx, groupID, userID)
}

// Ranking returns the member ranking list with profile image URLs.
func (s *Member) Ranking(ctx context.Context, groupID uuid.UUID) ([]MemberResponse, error) {
	rows, err := s.q.GetGroupRanking(ctx, groupID)
	if err != nil {
		return nil, err
	}
	out := make([]MemberResponse, 0, len(rows))
	for _, r := range rows {
		m := MemberResponse{
			UserID: r.UserID, Username: r.Username, Ranking: r.Points,
			SelectedBatch: r.AchievementID,
		}
		if s.obj != nil {
			if u, _ := s.obj.PresignedGet(ctx, UserProfileKey(r.UserID, true)); u != "" {
				m.ProfileImageSmall = &u
			}
		}
		out = append(out, m)
	}
	return out, nil
}
