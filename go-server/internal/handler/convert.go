package handler

import (
	"context"
	"math/rand"
	"time"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func toGroupDto(g *service.GroupDTO) genserver.GroupDto {
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
	return genserver.GroupDto{
		Id:                g.ID.String(),
		Name:              g.Name,
		Description:       desc,
		Link:              link,
		Visibility:        int32(g.Visibility),
		GroupAdmin:        g.AdminID.String(),
		InviteUrl:         inviteUrl,
		ProfileImage:      profileImage,
		ProfileImageSmall: profileImageSmall,
		PinImage:          pinImage,
		LastUpdated:       lastUpdated,
	}
}

func toUserInfoDto(u *service.UserInfo) genserver.UserInfoDto {
	desc := ""
	if u.Description != nil {
		desc = *u.Description
	}
	return genserver.UserInfoDto{
		UserId:      u.ID.String(),
		Username:    u.Username,
		Description: desc,
	}
}

func toTokenResponseDto(p *service.TokenPair) genserver.TokenResponseDto {
	return genserver.TokenResponseDto{
		AccessToken:  p.AccessToken,
		RefreshToken: p.RefreshToken.String(),
		UserId:       p.UserID.String(),
	}
}

// ctxUserID extracts the authenticated user's UUID from context.
func ctxUserID(ctx context.Context) (uuid.UUID, bool) {
	return middleware.UserID(ctx)
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
