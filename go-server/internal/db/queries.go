// Package db provides a thin, idiomatic-Go facade over the sqlc-generated
// queries in internal/gen/db (dbgen). All raw SQL lives in queries/*.sql; this
// file is pure type plumbing — no SQL strings.
package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

type Queries struct {
	pool *pgxpool.Pool
	g    *dbgen.Queries
}

func New(pool *pgxpool.Pool) *Queries {
	return &Queries{pool: pool, g: dbgen.New(pool)}
}

// Gen returns the underlying sqlc-generated Queries for callers that want to
// work with pgtype directly (e.g. PostGIS queries).
func (q *Queries) Gen() *dbgen.Queries { return q.g }
func (q *Queries) Pool() *pgxpool.Pool { return q.pool }

// ---- conversion helpers ----

func pgUUID(id uuid.UUID) pgtype.UUID   { return pgtype.UUID{Bytes: id, Valid: true} }
func goUUID(p pgtype.UUID) uuid.UUID    { return uuid.UUID(p.Bytes) }
func pgText(s *string) pgtype.Text      { if s == nil { return pgtype.Text{} }; return pgtype.Text{String: *s, Valid: true} }
func pgTextS(s string) pgtype.Text      { return pgtype.Text{String: s, Valid: true} }
func goText(p pgtype.Text) *string      { if !p.Valid { return nil }; v := p.String; return &v }
func pgTZ(t *time.Time) pgtype.Timestamptz {
	if t == nil { return pgtype.Timestamptz{} }
	return pgtype.Timestamptz{Time: *t, Valid: true}
}
func goTZ(p pgtype.Timestamptz) *time.Time { if !p.Valid { return nil }; v := p.Time; return &v }

// ---- Users ----

type User struct {
	ID                      uuid.UUID
	Username                string
	Email                   *string
	Password                string
	XP                      int64
	Description             *string
	ProfilePictureExists    bool
	EmailConfirmed          bool
	FailedLoginAttempts     int
	FirebaseToken           *string
	Code                    *string
	CodeExpiration          *time.Time
	ResetPasswordUrl        *string
	ResetPasswordExpiration *time.Time
	DeletionUrl             *string
	EmailConfirmationUrl    *string
	LastUsernameUpdate      *time.Time
	SelectedBatch           *uuid.UUID
}

func (q *Queries) GetUserByID(ctx context.Context, id uuid.UUID) (*User, error) {
	row, err := q.g.GetUserByID(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return userFromIDRow(row), nil
}

func userFromIDRow(r dbgen.GetUserByIDRow) *User {
	var sb *uuid.UUID
	if r.SelectedBatch.Valid {
		u := goUUID(r.SelectedBatch)
		sb = &u
	}
	return &User{
		ID:                      goUUID(r.ID),
		Username:                r.Username.String,
		Email:                   goText(r.Email),
		Password:                r.Password.String,
		XP:                      int64(r.Xp),
		Description:             goText(r.Description),
		ProfilePictureExists:    r.ProfilePictureExists,
		EmailConfirmed:          r.EmailConfirmed,
		FailedLoginAttempts:     int(r.FailedLoginAttempts),
		FirebaseToken:           goText(r.FirebaseToken),
		Code:                    goText(r.Code),
		CodeExpiration:          goTZ(r.CodeExpiration),
		ResetPasswordUrl:        goText(r.ResetPasswordUrl),
		ResetPasswordExpiration: goTZ(r.ResetPasswordExpiration),
		DeletionUrl:             goText(r.DeletionUrl),
		EmailConfirmationUrl:    goText(r.EmailConfirmationUrl),
		LastUsernameUpdate:      goTZ(r.LastUsernameUpdate),
		SelectedBatch:           sb,
	}
}

func (q *Queries) GetUserByUsername(ctx context.Context, username string) (*User, error) {
	row, err := q.g.GetUserByUsername(ctx, pgTextS(username))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	// reuse converter by copying into the wider row shape
	return &User{
		ID:                      goUUID(row.ID),
		Username:                row.Username.String,
		Email:                   goText(row.Email),
		Password:                row.Password.String,
		XP:                      int64(row.Xp),
		Description:             goText(row.Description),
		ProfilePictureExists:    row.ProfilePictureExists,
		EmailConfirmed:          row.EmailConfirmed,
		FailedLoginAttempts:     int(row.FailedLoginAttempts),
		FirebaseToken:           goText(row.FirebaseToken),
		Code:                    goText(row.Code),
		CodeExpiration:          goTZ(row.CodeExpiration),
		ResetPasswordUrl:        goText(row.ResetPasswordUrl),
		ResetPasswordExpiration: goTZ(row.ResetPasswordExpiration),
		DeletionUrl:             goText(row.DeletionUrl),
		EmailConfirmationUrl:    goText(row.EmailConfirmationUrl),
		LastUsernameUpdate:      goTZ(row.LastUsernameUpdate),
	}, nil
}

func (q *Queries) GetUsernameByID(ctx context.Context, id uuid.UUID) (string, error) {
	t, err := q.g.GetUsernameByID(ctx, pgUUID(id))
	if err != nil {
		return "", err
	}
	return t.String, nil
}

func (q *Queries) CreateUser(ctx context.Context, username, passwordHash string, email *string) (uuid.UUID, error) {
	id := uuid.New()
	_, err := q.g.CreateUser(ctx, dbgen.CreateUserParams{
		ID:       pgUUID(id),
		Username: pgTextS(username),
		Password: pgTextS(passwordHash),
		Email:    pgText(email),
	})
	return id, err
}

func (q *Queries) IncrementFailedLogin(ctx context.Context, id uuid.UUID) error {
	return q.g.IncrementFailedLogin(ctx, pgUUID(id))
}

func (q *Queries) ResetFailedLogin(ctx context.Context, id uuid.UUID) error {
	return q.g.ResetFailedLogin(ctx, pgUUID(id))
}

func (q *Queries) SoftDeleteUser(ctx context.Context, id uuid.UUID) error {
	return q.g.SoftDeleteUser(ctx, pgUUID(id))
}

func (q *Queries) UpdateUserDescription(ctx context.Context, id uuid.UUID, desc *string) error {
	return q.g.UpdateUserDescription(ctx, dbgen.UpdateUserDescriptionParams{ID: pgUUID(id), Description: pgText(desc)})
}
func (q *Queries) UpdateUserFirebaseToken(ctx context.Context, id uuid.UUID, token *string) error {
	return q.g.UpdateUserFirebaseToken(ctx, dbgen.UpdateUserFirebaseTokenParams{ID: pgUUID(id), FirebaseToken: pgText(token)})
}
func (q *Queries) UpdateUserUsername(ctx context.Context, id uuid.UUID, username string) error {
	return q.g.UpdateUserUsername(ctx, dbgen.UpdateUserUsernameParams{ID: pgUUID(id), Username: pgTextS(username)})
}
func (q *Queries) UpdateUserPassword(ctx context.Context, id uuid.UUID, hash string) error {
	return q.g.UpdateUserPassword(ctx, dbgen.UpdateUserPasswordParams{ID: pgUUID(id), Password: pgTextS(hash)})
}
func (q *Queries) UpdateUserEmail(ctx context.Context, id uuid.UUID, email, confirmationUrl *string) error {
	return q.g.UpdateUserEmail(ctx, dbgen.UpdateUserEmailParams{
		ID:                   pgUUID(id),
		Email:                pgText(email),
		EmailConfirmationUrl: pgText(confirmationUrl),
	})
}
func (q *Queries) SetUserProfilePictureExists(ctx context.Context, id uuid.UUID, exists bool) error {
	return q.g.SetUserProfilePictureExists(ctx, dbgen.SetUserProfilePictureExistsParams{ID: pgUUID(id), ProfilePictureExists: exists})
}
func (q *Queries) GetUserByIDAndCode(ctx context.Context, id uuid.UUID, code string) (bool, error) {
	_, err := q.g.GetUserByIDAndCode(ctx, dbgen.GetUserByIDAndCodeParams{ID: pgUUID(id), Code: pgTextS(code)})
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}
func (q *Queries) AddUserXp(ctx context.Context, id uuid.UUID, delta int32) error {
	return q.g.AddUserXp(ctx, dbgen.AddUserXpParams{ID: pgUUID(id), Xp: delta})
}
func (q *Queries) SetUserRecoveryCode(ctx context.Context, id uuid.UUID, code string, exp time.Time) error {
	return q.g.SetUserRecoveryCode(ctx, dbgen.SetUserRecoveryCodeParams{
		ID: pgUUID(id), Code: pgTextS(code), CodeExpiration: pgTZ(&exp),
	})
}
func (q *Queries) SetUserDeletionUrl(ctx context.Context, id uuid.UUID, url string, exp time.Time) error {
	return q.g.SetUserDeletionUrl(ctx, dbgen.SetUserDeletionUrlParams{
		ID: pgUUID(id), DeletionUrl: pgTextS(url), CodeExpiration: pgTZ(&exp),
	})
}
func (q *Queries) SetUserResetPasswordUrl(ctx context.Context, id uuid.UUID, url string, exp time.Time) error {
	return q.g.SetUserResetPasswordUrl(ctx, dbgen.SetUserResetPasswordUrlParams{
		ID: pgUUID(id), ResetPasswordUrl: pgTextS(url), ResetPasswordExpiration: pgTZ(&exp),
	})
}
func (q *Queries) ConfirmUserEmail(ctx context.Context, id uuid.UUID) error {
	return q.g.ConfirmUserEmail(ctx, pgUUID(id))
}

// ---- Refresh tokens ----

func (q *Queries) CreateRefreshToken(ctx context.Context, userID uuid.UUID) (uuid.UUID, error) {
	tok := uuid.New()
	err := q.g.CreateRefreshToken(ctx, dbgen.CreateRefreshTokenParams{
		ID:     pgUUID(uuid.New()),
		Token:  pgUUID(tok),
		UserID: pgUUID(userID),
	})
	return tok, err
}

func (q *Queries) FindRefreshToken(ctx context.Context, token uuid.UUID) (uuid.UUID, error) {
	p, err := q.g.FindRefreshToken(ctx, pgUUID(token))
	if err != nil {
		return uuid.Nil, err
	}
	return goUUID(p), nil
}

func (q *Queries) TouchRefreshToken(ctx context.Context, token uuid.UUID) error {
	return q.g.TouchRefreshToken(ctx, pgUUID(token))
}

func (q *Queries) InvalidateUserTokens(ctx context.Context, userID uuid.UUID) error {
	return q.g.InvalidateUserTokens(ctx, pgUUID(userID))
}

// ---- Groups ----

type Group struct {
	ID           uuid.UUID
	Name         string
	Description  *string
	Link         *string
	Visibility   int
	AdminID      uuid.UUID
	InviteUrl    *string
	CreationDate *time.Time
	UpdateDate   *time.Time
}

func (q *Queries) CreateGroup(ctx context.Context, g Group) (uuid.UUID, error) {
	if g.ID == uuid.Nil {
		g.ID = uuid.New()
	}
	err := q.g.CreateGroup(ctx, dbgen.CreateGroupParams{
		ID:          pgUUID(g.ID),
		Name:        pgText(&g.Name),
		Description: pgText(g.Description),
		Link:        pgText(g.Link),
		Visibility:  pgtype.Int4{Int32: int32(g.Visibility), Valid: true},
		AdminID:     pgUUID(g.AdminID),
		InviteUrl:   pgText(g.InviteUrl),
	})
	return g.ID, err
}

func (q *Queries) GetGroupByID(ctx context.Context, id uuid.UUID) (*Group, error) {
	row, err := q.g.GetGroupByID(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	vis := 0
	if row.Visibility.Valid {
		vis = int(row.Visibility.Int32)
	}
	return &Group{
		ID:           goUUID(row.ID),
		Name:         row.Name.String,
		Description:  goText(row.Description),
		Link:         goText(row.Link),
		Visibility:   vis,
		AdminID:      goUUID(row.AdminID),
		InviteUrl:    goText(row.InviteUrl),
		CreationDate: goTZ(row.CreationDate),
		UpdateDate:   goTZ(row.UpdateDate),
	}, nil
}

func (q *Queries) GroupExistsByName(ctx context.Context, name string) (bool, error) {
	return q.g.GroupExistsByName(ctx, pgTextS(name))
}

func (q *Queries) GetGroupAdminUsername(ctx context.Context, id uuid.UUID) (string, error) {
	t, err := q.g.GetGroupAdminUsername(ctx, pgUUID(id))
	if err != nil {
		return "", err
	}
	return t.String, nil
}

type GroupUpdate struct {
	Name        *string
	Description *string
	Link        *string
	Visibility  *int
	AdminID     *uuid.UUID
	InviteUrl   *string
}

func (q *Queries) UpdateGroup(ctx context.Context, id uuid.UUID, u GroupUpdate) error {
	p := dbgen.UpdateGroupParams{ID: pgUUID(id)}
	if u.Name != nil {
		p.Name = pgTextS(*u.Name)
	}
	if u.Description != nil {
		p.Description = pgTextS(*u.Description)
	}
	if u.Link != nil {
		p.Link = pgTextS(*u.Link)
	}
	if u.Visibility != nil {
		p.Visibility = pgtype.Int4{Int32: int32(*u.Visibility), Valid: true}
	}
	if u.AdminID != nil {
		p.AdminID = pgUUID(*u.AdminID)
	}
	if u.InviteUrl != nil {
		p.InviteUrl = pgTextS(*u.InviteUrl)
	}
	return q.g.UpdateGroup(ctx, p)
}

func (q *Queries) SoftDeleteGroup(ctx context.Context, id uuid.UUID) error {
	return q.g.SoftDeleteGroup(ctx, pgUUID(id))
}

type GroupSearch struct {
	Search       *string
	UpdatedAfter *time.Time
	UserID       *uuid.UUID
	WithUser     *bool // nil = any; true = only user's; false = only not-user's
	Limit        int32
	Offset       int32
}

func (q *Queries) SearchGroups(ctx context.Context, s GroupSearch) ([]Group, error) {
	search := pgtype.Text{}
	if s.Search != nil {
		search = pgTextS(*s.Search)
	}
	after := pgTZ(s.UpdatedAfter)
	if s.Limit == 0 {
		s.Limit = 20
	}
	var rows []groupRow
	if s.WithUser == nil {
		rs, err := q.g.SearchGroups(ctx, dbgen.SearchGroupsParams{
			Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow(r))
		}
	} else if *s.WithUser {
		if s.UserID == nil {
			return nil, errors.New("withUser requires userId")
		}
		rs, err := q.g.SearchGroupsInUser(ctx, dbgen.SearchGroupsInUserParams{
			UserID: pgUUID(*s.UserID), Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow(r))
		}
	} else {
		if s.UserID == nil {
			return nil, errors.New("withUser requires userId")
		}
		rs, err := q.g.SearchGroupsNotInUser(ctx, dbgen.SearchGroupsNotInUserParams{
			UserID: pgUUID(*s.UserID), Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow(r))
		}
	}
	out := make([]Group, 0, len(rows))
	for _, r := range rows {
		vis := 0
		if r.Visibility.Valid {
			vis = int(r.Visibility.Int32)
		}
		out = append(out, Group{
			ID: goUUID(r.ID), Name: r.Name.String, Description: goText(r.Description),
			Link: goText(r.Link), Visibility: vis, AdminID: goUUID(r.AdminID),
			InviteUrl: goText(r.InviteUrl),
			CreationDate: goTZ(r.CreationDate), UpdateDate: goTZ(r.UpdateDate),
		})
	}
	return out, nil
}

type groupRow struct {
	ID           pgtype.UUID
	Name         pgtype.Text
	Description  pgtype.Text
	Link         pgtype.Text
	Visibility   pgtype.Int4
	AdminID      pgtype.UUID
	InviteUrl    pgtype.Text
	CreationDate pgtype.Timestamptz
	UpdateDate   pgtype.Timestamptz
}

func (q *Queries) ListDeletedGroupsAfter(ctx context.Context, after time.Time) ([]uuid.UUID, error) {
	rs, err := q.g.ListDeletedGroupsAfter(ctx, pgTZ(&after))
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, len(rs))
	for i, r := range rs {
		out[i] = goUUID(r)
	}
	return out, nil
}

// LogDeletion marks an entity as deleted in the audit table (matches
// Spring's delete_log behavior). entityType: 1=user, 2=group, 3=pin.
func (q *Queries) LogDeletion(ctx context.Context, entityType int16, id uuid.UUID) error {
	return q.g.LogDeletion(ctx, dbgen.LogDeletionParams{
		DeletedEntityType: entityType,
		DeletedEntityID:   pgUUID(id),
	})
}

// ---- Members ----

type GroupMember struct {
	UserID   uuid.UUID
	Username string
	IsAdmin  bool
}

func (q *Queries) AddMember(ctx context.Context, groupID, userID uuid.UUID) error {
	return q.g.AddMember(ctx, dbgen.AddMemberParams{GroupID: pgUUID(groupID), UserID: pgUUID(userID)})
}

func (q *Queries) RemoveMember(ctx context.Context, groupID, userID uuid.UUID) error {
	return q.g.RemoveMember(ctx, dbgen.RemoveMemberParams{GroupID: pgUUID(groupID), UserID: pgUUID(userID)})
}

func (q *Queries) ListGroupMembers(ctx context.Context, groupID uuid.UUID) ([]GroupMember, error) {
	rs, err := q.g.ListGroupMembers(ctx, pgUUID(groupID))
	if err != nil {
		return nil, err
	}
	out := make([]GroupMember, 0, len(rs))
	for _, r := range rs {
		out = append(out, GroupMember{UserID: goUUID(r.UserID), Username: r.Username.String, IsAdmin: r.IsAdmin})
	}
	return out, nil
}

func (q *Queries) IsMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	return q.g.IsMember(ctx, dbgen.IsMemberParams{GroupID: pgUUID(groupID), UserID: pgUUID(userID)})
}

func (q *Queries) CountGroupMembers(ctx context.Context, groupID uuid.UUID) (int64, error) {
	return q.g.CountGroupMembers(ctx, pgUUID(groupID))
}

// ---- Guards ----

func (q *Queries) IsGroupAdmin(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	return q.g.IsGroupAdmin(ctx, dbgen.IsGroupAdminParams{ID: pgUUID(groupID), AdminID: pgUUID(userID)})
}
func (q *Queries) IsGroupMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	return q.g.IsGroupMember(ctx, dbgen.IsGroupMemberParams{GroupID: pgUUID(groupID), UserID: pgUUID(userID)})
}
func (q *Queries) IsGroupVisible(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	return q.g.IsGroupVisible(ctx, dbgen.IsGroupVisibleParams{ID: pgUUID(groupID), UserID: pgUUID(userID)})
}
func (q *Queries) IsPinCreator(ctx context.Context, pinID, userID uuid.UUID) (bool, error) {
	return q.g.IsPinCreator(ctx, dbgen.IsPinCreatorParams{ID: pgUUID(pinID), CreatorID: pgUUID(userID)})
}
func (q *Queries) IsPinGroupAdmin(ctx context.Context, pinID, userID uuid.UUID) (bool, error) {
	return q.g.IsPinGroupAdmin(ctx, dbgen.IsPinGroupAdminParams{ID: pgUUID(pinID), AdminID: pgUUID(userID)})
}
func (q *Queries) IsPinPublicOrMember(ctx context.Context, pinID, userID uuid.UUID) (bool, error) {
	return q.g.IsPinPublicOrMember(ctx, dbgen.IsPinPublicOrMemberParams{ID: pgUUID(pinID), UserID: pgUUID(userID)})
}

// ---- Likes ----

type UserLikedPin struct {
	PinID           uuid.UUID
	LikeAll         bool
	LikeLocation    bool
	LikePhotography bool
	LikeArt         bool
}

func (q *Queries) ListUserLikedPins(ctx context.Context, userID uuid.UUID) ([]UserLikedPin, error) {
	rows, err := q.g.ListUserLikedPins(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]UserLikedPin, 0, len(rows))
	for _, r := range rows {
		out = append(out, UserLikedPin{
			PinID:           goUUID(r.PinID),
			LikeAll:         r.LikeAll,
			LikeLocation:    r.LikeLocation,
			LikePhotography: r.LikePhotography,
			LikeArt:         r.LikeArt,
		})
	}
	return out, nil
}

// ---- Achievements ----

type UserAchievement struct {
	AchievementID int32
	Claimed       bool
}

func (q *Queries) ListUserAchievements(ctx context.Context, userID uuid.UUID) ([]UserAchievement, error) {
	rows, err := q.g.ListUserAchievements(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]UserAchievement, 0, len(rows))
	for _, r := range rows {
		out = append(out, UserAchievement{AchievementID: r.AchievementID, Claimed: r.Claimed})
	}
	return out, nil
}

func (q *Queries) ClaimUserAchievement(ctx context.Context, userID uuid.UUID, achievementID int32) error {
	return q.g.ClaimUserAchievement(ctx, dbgen.ClaimUserAchievementParams{UserID: pgUUID(userID), AchievementID: achievementID})
}
