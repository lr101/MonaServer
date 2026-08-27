package handler

import (
	"context"
	"math/rand"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func toGroupDto(g *service.GroupDTO, includePrivateFields bool) genserver.GroupDto {
	inviteUrl := ""
	if g.InviteUrl != nil {
		inviteUrl = *g.InviteUrl
	}
	profileImage := ""
	if g.ProfileImage != nil {
		profileImage = *g.ProfileImage
	}
	profileImageSmall := ""
	if g.ProfileSmall != nil {
		profileImageSmall = *g.ProfileSmall
	}
	pinImage := ""
	if g.PinImage != nil {
		pinImage = *g.PinImage
	}
	desc := ""
	if g.Description != nil {
		desc = *g.Description
	}
	link := ""
	if g.Link != nil {
		link = *g.Link
	}
	var lastUpdated time.Time
	if g.UpdateDate != nil {
		lastUpdated = *g.UpdateDate
	}
	out := genserver.GroupDto{
		Id:                g.ID.String(),
		Name:              g.Name,
		Visibility:        int32(g.Visibility),
		ProfileImage:      profileImage,
		ProfileImageSmall: profileImageSmall,
		PinImage:          pinImage,
	}
	if includePrivateFields {
		out.Description = desc
		out.Link = link
		out.GroupAdmin = g.AdminID.String()
		out.InviteUrl = inviteUrl
		out.LastUpdated = lastUpdated
	}
	out.BestSeason = toSeasonItemDto(g.BestSeason)
	return out
}

func toUserInfoDto(u *service.UserInfo) genserver.UserInfoDto {
	desc := ""
	if u.Description != nil {
		desc = *u.Description
	}
	return genserver.UserInfoDto{
		UserId:                u.ID.String(),
		Username:              u.Username,
		Description:           desc,
		SelectedBatch:         u.SelectedBatch,
		BestSeason:            toSeasonItemDto(u.BestSeason),
		IsMessagingRegistered: u.IsMessagingRegistered,
	}
}

func toSeasonItemDto(item *db.SeasonItem) *genserver.SeasonItemDto {
	if item == nil {
		return nil
	}
	return &genserver.SeasonItemDto{
		Id:     item.ID.String(),
		Rank:   item.Rank,
		Points: item.Points,
		Season: genserver.SeasonDto{
			Id:           item.SeasonID.String(),
			SeasonNumber: item.SeasonNumber,
			Year:         item.Year,
			Month:        item.Month,
		},
	}
}

func toTokenResponseDto(p *service.TokenPair) genserver.TokenResponseDto {
	return genserver.TokenResponseDto{
		AccessToken:  p.AccessToken,
		RefreshToken: p.RefreshToken.String(),
		UserId:       p.UserID.String(),
	}
}

// serviceErrResp converts a service/domain error to the tagged server's plain-text response.
func serviceErrResp(err error) genserver.ImplResponse {
	return genserver.Response(apperrors.HTTPStatus(err), []byte(apperrors.Message(err)))
}

// ctxUserID extracts the authenticated user's UUID from context.
func ctxUserID(ctx context.Context) (uuid.UUID, bool) {
	return middleware.UserID(ctx)
}

// ctxIsAdmin reports whether the authenticated caller has the ADMIN role.
func ctxIsAdmin(ctx context.Context) bool {
	return middleware.Role(ctx) == middleware.RoleAdmin
}

func strDeref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

const alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

func optStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func randomAlphaStr(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = alpha[rand.Intn(len(alpha))]
	}
	return string(b)
}
