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

	"github.com/lrprojects/monaserver/internal/apperrors"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

type Queries struct {
	pool   *pgxpool.Pool
	runner dbgen.DBTX
	g      *dbgen.Queries
	// inTx is true for a facade backed by a caller-owned transaction.  Methods
	// that need an atomic claim/security update can start a transaction only at
	// the outer edge and never accidentally nest one.
	inTx bool
}

func New(pool *pgxpool.Pool) *Queries {
	return &Queries{pool: pool, runner: pool, g: dbgen.New(pool)}
}

// Gen returns the underlying sqlc-generated Queries for callers that want to
// work with pgtype directly (e.g. PostGIS queries).
func (q *Queries) Gen() *dbgen.Queries { return q.g }

// Pool returns the root connection pool.  A transaction facade deliberately
// has no pool so callbacks cannot escape their caller-owned transaction.
func (q *Queries) Pool() *pgxpool.Pool {
	if q.inTx {
		return nil
	}
	return q.pool
}

func (q *Queries) InTx(ctx context.Context, fn func(*Queries) error) error {
	if q.inTx {
		return fn(q)
	}
	tx, err := q.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txQueries := &Queries{runner: tx, g: q.g.WithTx(tx), inTx: true}
	if err := fn(txQueries); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// ---- conversion helpers ----

func pgUUID(id uuid.UUID) pgtype.UUID { return pgtype.UUID{Bytes: id, Valid: true} }
func pgUUIDPtr(id *uuid.UUID) pgtype.UUID {
	if id == nil {
		return pgtype.UUID{}
	}
	return pgUUID(*id)
}
func goUUID(p pgtype.UUID) uuid.UUID { return uuid.UUID(p.Bytes) }
func goUUIDPtr(p pgtype.UUID) *uuid.UUID {
	if !p.Valid {
		return nil
	}
	id := goUUID(p)
	return &id
}
func pgText(s *string) pgtype.Text {
	if s == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *s, Valid: true}
}
func pgTextS(s string) pgtype.Text { return pgtype.Text{String: s, Valid: true} }
func goText(p pgtype.Text) *string {
	if !p.Valid {
		return nil
	}
	v := p.String
	return &v
}
func pgTZ(t *time.Time) pgtype.Timestamptz {
	if t == nil {
		return pgtype.Timestamptz{}
	}
	return pgtype.Timestamptz{Time: *t, Valid: true}
}
func goTZ(p pgtype.Timestamptz) *time.Time {
	if !p.Valid {
		return nil
	}
	v := p.Time
	return &v
}

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
	AuthGeneration          int64
	SecurityState           string
	PasswordDisabled        bool
	PasswordResetRequired   bool
	CompromisedAt           *time.Time
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
		AuthGeneration:          r.AuthGeneration,
		SecurityState:           r.SecurityState,
		PasswordDisabled:        r.PasswordDisabled,
		PasswordResetRequired:   r.PasswordResetRequired,
		CompromisedAt:           goTZ(r.CompromisedAt),
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
		AuthGeneration:          row.AuthGeneration,
		SecurityState:           row.SecurityState,
		PasswordDisabled:        row.PasswordDisabled,
		PasswordResetRequired:   row.PasswordResetRequired,
		CompromisedAt:           goTZ(row.CompromisedAt),
	}, nil
}

func (q *Queries) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	r, err := q.g.GetUserByEmail(ctx, email)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
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
		AuthGeneration:          r.AuthGeneration,
		SecurityState:           r.SecurityState,
		PasswordDisabled:        r.PasswordDisabled,
		PasswordResetRequired:   r.PasswordResetRequired,
		CompromisedAt:           goTZ(r.CompromisedAt),
	}, nil
}

func (q *Queries) GetUsernameByID(ctx context.Context, id uuid.UUID) (string, error) {
	t, err := q.g.GetUsernameByID(ctx, pgUUID(id))
	if err != nil {
		return "", err
	}
	return t.String, nil
}

func (q *Queries) CreateUser(ctx context.Context, username, passwordHash string, email, confirmationURL *string) (uuid.UUID, error) {
	id := uuid.New()
	_, err := q.g.CreateUser(ctx, dbgen.CreateUserParams{
		ID:                   pgUUID(id),
		Username:             pgTextS(username),
		Password:             pgTextS(passwordHash),
		Email:                pgText(email),
		EmailConfirmationUrl: pgText(confirmationURL),
	})
	return id, err
}

func (q *Queries) IncrementFailedLogin(ctx context.Context, id uuid.UUID) error {
	return q.g.IncrementFailedLogin(ctx, pgUUID(id))
}

func (q *Queries) ResetFailedLogin(ctx context.Context, id uuid.UUID) error {
	return q.g.ResetFailedLogin(ctx, pgUUID(id))
}

func (q *Queries) ListAdminGroupIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := q.g.ListAdminGroupIDs(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, len(rows))
	for i, id := range rows {
		ids[i] = goUUID(id)
	}
	return ids, nil
}

func (q *Queries) ListPinIDsRemovedWithUser(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := q.g.ListPinIDsRemovedWithUser(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, len(rows))
	for i, id := range rows {
		ids[i] = goUUID(id)
	}
	return ids, nil
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
	return q.ChangeUserEmail(ctx, id, email, confirmationUrl)
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
func (q *Queries) AwardGroupXP(ctx context.Context, groupID uuid.UUID, awardKey string, amount int32) error {
	return q.g.AwardGroupXP(ctx, dbgen.AwardGroupXPParams{
		GroupID: pgUUID(groupID), AwardKey: awardKey, XpAwarded: amount,
	})
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

type UserURLLookup struct {
	ID         uuid.UUID
	Username   string
	Expiration *time.Time
}

func (q *Queries) GetUserByResetPasswordUrl(ctx context.Context, url string) (*UserURLLookup, error) {
	r, err := q.g.GetUserByResetPasswordUrl(ctx, pgTextS(url))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &UserURLLookup{ID: goUUID(r.ID), Username: r.Username.String, Expiration: goTZ(r.ResetPasswordExpiration)}, nil
}

func (q *Queries) GetUserByDeletionUrl(ctx context.Context, url string) (*UserURLLookup, error) {
	r, err := q.g.GetUserByDeletionUrl(ctx, pgTextS(url))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &UserURLLookup{ID: goUUID(r.ID), Username: r.Username.String, Expiration: goTZ(r.CodeExpiration)}, nil
}

func (q *Queries) GetUserByEmailConfirmationUrl(ctx context.Context, url string) (*UserURLLookup, error) {
	r, err := q.g.GetUserByEmailConfirmationUrl(ctx, pgTextS(url))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &UserURLLookup{ID: goUUID(r.ID), Username: r.Username.String}, nil
}

func (q *Queries) ConfirmUserEmail(ctx context.Context, id uuid.UUID) error {
	confirmed, err := q.ConfirmUserEmailWithClaim(ctx, id)
	if err != nil {
		return err
	}
	if !confirmed {
		return ErrEmailClaimUnavailable
	}
	return nil
}

func (q *Queries) ListAllUserEmails(ctx context.Context) ([]string, error) {
	rs, err := q.g.ListAllUserEmails(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(rs))
	for _, r := range rs {
		if r.Valid {
			out = append(out, r.String)
		}
	}
	return out, nil
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

type RefreshToken struct {
	UserID         uuid.UUID
	LastActiveDate time.Time
}

func (q *Queries) FindRefreshToken(ctx context.Context, token uuid.UUID) (*RefreshToken, error) {
	p, err := q.g.FindRefreshToken(ctx, pgUUID(token))
	if err != nil {
		return nil, err
	}
	return &RefreshToken{UserID: goUUID(p.UserID), LastActiveDate: p.LastActiveDate.Time}, nil
}

func (q *Queries) TouchRefreshToken(ctx context.Context, token uuid.UUID) error {
	return q.g.TouchRefreshToken(ctx, pgUUID(token))
}

func (q *Queries) DeleteRefreshToken(ctx context.Context, token uuid.UUID) error {
	return q.g.DeleteRefreshToken(ctx, pgUUID(token))
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
	PinStyle     string
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
		PinStyle:     row.PinStyle,
	}, nil
}

func (q *Queries) GetGroupXP(ctx context.Context, id uuid.UUID) (int32, error) {
	return q.g.GetGroupXP(ctx, pgUUID(id))
}

func (q *Queries) LockGroupForDelete(ctx context.Context, id uuid.UUID) (bool, error) {
	_, err := q.g.LockGroupForDelete(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
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
	Name           *string
	Description    *string
	Link           *string
	Visibility     *int
	AdminID        *uuid.UUID
	InviteUrl      *string
	ClearInviteURL bool
	PinStyle       *string
}

func (q *Queries) UpdateGroup(ctx context.Context, id uuid.UUID, u GroupUpdate) error {
	p := dbgen.UpdateGroupParams{ID: pgUUID(id), ClearInviteUrl: u.ClearInviteURL}
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
	if u.PinStyle != nil {
		p.PinStyle = pgTextS(*u.PinStyle)
	}
	return q.g.UpdateGroup(ctx, p)
}

func (q *Queries) SoftDeleteGroup(ctx context.Context, id uuid.UUID) error {
	return q.g.SoftDeleteGroup(ctx, pgUUID(id))
}

func (q *Queries) HardDeleteGroup(ctx context.Context, id uuid.UUID) error {
	return q.g.HardDeleteGroup(ctx, pgUUID(id))
}

type GroupSearch struct {
	IDs          []uuid.UUID
	Search       *string
	UpdatedAfter *time.Time
	UserID       *uuid.UUID
	WithUser     *bool // nil = any; true = only user's; false = only not-user's
	Limit        int32
	Offset       int32
}

func (q *Queries) SearchGroups(ctx context.Context, s GroupSearch) ([]Group, error) {
	ids := make([]pgtype.UUID, len(s.IDs))
	for i, id := range s.IDs {
		ids[i] = pgUUID(id)
	}
	search := pgtype.Text{}
	if s.Search != nil {
		search = pgTextS(*s.Search)
	}
	after := pgTZ(s.UpdatedAfter)
	if s.Limit <= 0 {
		s.Limit = 1<<31 - 1
	}
	var rows []groupRow
	if s.WithUser == nil {
		rs, err := q.g.SearchGroups(ctx, dbgen.SearchGroupsParams{
			Ids: ids, Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow{
				ID: r.ID, Name: r.Name, Description: r.Description, Link: r.Link,
				Visibility: r.Visibility, AdminID: r.AdminID, InviteUrl: r.InviteUrl,
				CreationDate: r.CreationDate, UpdateDate: r.UpdateDate, PinStyle: pgtype.Text{String: r.PinStyle, Valid: true},
			})
		}
	} else if *s.WithUser {
		if s.UserID == nil {
			return nil, errors.New("withUser requires userId")
		}
		rs, err := q.g.SearchGroupsInUser(ctx, dbgen.SearchGroupsInUserParams{
			UserID: pgUUID(*s.UserID), Ids: ids, Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow{
				ID: r.ID, Name: r.Name, Description: r.Description, Link: r.Link,
				Visibility: r.Visibility, AdminID: r.AdminID, InviteUrl: r.InviteUrl,
				CreationDate: r.CreationDate, UpdateDate: r.UpdateDate, PinStyle: pgtype.Text{String: r.PinStyle, Valid: true},
			})
		}
	} else {
		if s.UserID == nil {
			return nil, errors.New("withUser requires userId")
		}
		rs, err := q.g.SearchGroupsNotInUser(ctx, dbgen.SearchGroupsNotInUserParams{
			UserID: pgUUID(*s.UserID), Ids: ids, Search: search, UpdatedAfter: after, Lim: s.Limit, Off: s.Offset,
		})
		if err != nil {
			return nil, err
		}
		for _, r := range rs {
			rows = append(rows, groupRow{
				ID: r.ID, Name: r.Name, Description: r.Description, Link: r.Link,
				Visibility: r.Visibility, AdminID: r.AdminID, InviteUrl: r.InviteUrl,
				CreationDate: r.CreationDate, UpdateDate: r.UpdateDate, PinStyle: pgtype.Text{String: r.PinStyle, Valid: true},
			})
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
			InviteUrl:    goText(r.InviteUrl),
			CreationDate: goTZ(r.CreationDate), UpdateDate: goTZ(r.UpdateDate),
			PinStyle: r.PinStyle.String,
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
	PinStyle     pgtype.Text
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

const (
	DeletedEntityGroup int16 = iota
	DeletedEntityPin
	DeletedEntityUser
)

// LogDeletion records an entity removal for incremental sync clients.
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

type GroupRanking struct {
	UserID        uuid.UUID
	Username      string
	Points        int32
	AchievementID *int32
}

func (q *Queries) GetGroupRanking(ctx context.Context, groupID uuid.UUID) ([]GroupRanking, error) {
	rs, err := q.g.GetGroupRanking(ctx, pgUUID(groupID))
	if err != nil {
		return nil, err
	}
	out := make([]GroupRanking, 0, len(rs))
	for _, r := range rs {
		var ach *int32
		if r.AchievementID.Valid {
			v := r.AchievementID.Int32
			ach = &v
		}
		out = append(out, GroupRanking{
			UserID: goUUID(r.UserID), Username: r.Username.String,
			Points: r.Points, AchievementID: ach,
		})
	}
	return out, nil
}

// ---- Ranking / Map ----

type UserRankingRow struct {
	UserID        uuid.UUID
	Username      string
	Description   *string
	Points        int32
	AchievementID *int32
}

type GroupRankingRow struct {
	GroupID     uuid.UUID
	Name        string
	Visibility  int
	Description *string
	Points      int32
}

type RankingFilter struct {
	Gid0, Gid1, Gid2 *string
	Since            *time.Time
	Limit, Offset    int32
}

func rankParams(f RankingFilter) (dbgen.GetUserRankingParams, dbgen.GetGlobalGroupRankingParams) {
	lim := f.Limit
	if lim <= 0 {
		lim = 1<<31 - 1
	}
	u := dbgen.GetUserRankingParams{
		Gid0: pgText(f.Gid0), Gid1: pgText(f.Gid1), Gid2: pgText(f.Gid2),
		Since: pgTZ(f.Since), Lim: lim, Off: f.Offset,
	}
	g := dbgen.GetGlobalGroupRankingParams{
		Gid0: pgText(f.Gid0), Gid1: pgText(f.Gid1), Gid2: pgText(f.Gid2),
		Since: pgTZ(f.Since), Lim: lim, Off: f.Offset,
	}
	return u, g
}

func (q *Queries) GetUserRanking(ctx context.Context, f RankingFilter) ([]UserRankingRow, error) {
	up, _ := rankParams(f)
	rs, err := q.g.GetUserRanking(ctx, up)
	if err != nil {
		return nil, err
	}
	out := make([]UserRankingRow, 0, len(rs))
	for _, r := range rs {
		var ach *int32
		if r.AchievementID.Valid {
			v := r.AchievementID.Int32
			ach = &v
		}
		out = append(out, UserRankingRow{
			UserID: goUUID(r.CreatorID), Username: r.Username.String,
			Description: goText(r.Description), Points: r.Points, AchievementID: ach,
		})
	}
	return out, nil
}

func (q *Queries) GetGlobalGroupRanking(ctx context.Context, f RankingFilter) ([]GroupRankingRow, error) {
	_, gp := rankParams(f)
	rs, err := q.g.GetGlobalGroupRanking(ctx, gp)
	if err != nil {
		return nil, err
	}
	out := make([]GroupRankingRow, 0, len(rs))
	for _, r := range rs {
		vis := 0
		if r.Visibility.Valid {
			vis = int(r.Visibility.Int32)
		}
		out = append(out, GroupRankingRow{
			GroupID: goUUID(r.GroupID), Name: r.Name.String,
			Visibility: vis, Description: goText(r.Description), Points: r.Points,
		})
	}
	return out, nil
}

func (q *Queries) GetGeoJson(ctx context.Context, gid0, gid1, gid2 *string) ([]string, error) {
	rs, err := q.g.GetGeoJson(ctx, dbgen.GetGeoJsonParams{
		Gid0: pgText(gid0), Gid1: pgText(gid1), Gid2: pgText(gid2),
	})
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(rs))
	for _, r := range rs {
		if s, ok := r.(string); ok {
			out = append(out, s)
		}
	}
	return out, nil
}

type MapInfoRow struct {
	ID                  uuid.UUID
	Gid0, Gid1, Gid2    *string
	Name0, Name1, Name2 *string
}

func (q *Queries) GetMapInfo(ctx context.Context, lat, lng float64) (*MapInfoRow, error) {
	row, err := q.g.GetMapInfo(ctx, dbgen.GetMapInfoParams{StPoint: lng, StPoint_2: lat})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &MapInfoRow{
		ID:   goUUID(row.ID),
		Gid0: goText(row.Gid0), Gid1: goText(row.Gid1), Gid2: goText(row.Gid2),
		Name0: goText(row.Name0), Name1: goText(row.Name1), Name2: goText(row.Name2),
	}, nil
}

type BoundarySearchRow struct {
	Level int32
	Gid   string
	Name  string
}

func (q *Queries) SearchBoundaries(ctx context.Context, search *string, limit, offset int32) ([]BoundarySearchRow, error) {
	lim := limit
	if lim == 0 {
		lim = 20
	}
	rs, err := q.g.SearchBoundaries(ctx, dbgen.SearchBoundariesParams{
		Search: pgText(search), Lim: lim, Off: offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]BoundarySearchRow, 0, len(rs))
	for _, r := range rs {
		out = append(out, BoundarySearchRow{Level: r.Level, Gid: r.Gid.String, Name: r.Name.String})
	}
	return out, nil
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

// ---- Pins ----

type Pin struct {
	ID              uuid.UUID
	Latitude        float64
	Longitude       float64
	CreationDate    *time.Time
	UpdateDate      *time.Time
	Title           *string
	Description     *string
	CreatorID       uuid.UUID
	GroupID         uuid.UUID
	StateProvinceID *uuid.UUID
	IsGone          bool
}

func pinFromRow(r dbgen.GetPinByIDRow) *Pin {
	var sp *uuid.UUID
	if r.StateProvinceID.Valid {
		u := goUUID(r.StateProvinceID)
		sp = &u
	}
	return &Pin{
		ID:              goUUID(r.ID),
		Latitude:        r.Latitude.Float64,
		Longitude:       r.Longitude.Float64,
		CreationDate:    goTZ(r.CreationDate),
		UpdateDate:      goTZ(r.UpdateDate),
		Title:           goText(r.Title),
		Description:     goText(r.Description),
		CreatorID:       goUUID(r.CreatorID),
		GroupID:         goUUID(r.GroupID),
		StateProvinceID: sp,
		IsGone:          r.IsGone,
	}
}

func (q *Queries) SetPinGone(ctx context.Context, id uuid.UUID, isGone bool) (bool, error) {
	rows, err := q.g.SetPinGone(ctx, dbgen.SetPinGoneParams{
		ID: pgUUID(id), IsGone: isGone,
	})
	return rows > 0, err
}

func (q *Queries) LockPinForDelete(ctx context.Context, id uuid.UUID) (bool, error) {
	_, err := q.g.LockPinForDelete(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) CreatePin(ctx context.Context, p Pin) (uuid.UUID, error) {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	var sp pgtype.UUID
	if p.StateProvinceID != nil {
		sp = pgUUID(*p.StateProvinceID)
	}
	err := q.g.CreatePin(ctx, dbgen.CreatePinParams{
		ID:              pgUUID(p.ID),
		Latitude:        pgtype.Float8{Float64: p.Latitude, Valid: true},
		Longitude:       pgtype.Float8{Float64: p.Longitude, Valid: true},
		CreationDate:    pgTZ(p.CreationDate),
		Title:           pgText(p.Title),
		Description:     pgText(p.Description),
		CreatorID:       pgUUID(p.CreatorID),
		GroupID:         pgUUID(p.GroupID),
		StateProvinceID: sp,
	})
	return p.ID, err
}

type PinPhoto struct {
	ID                  uuid.UUID
	PinID               uuid.UUID
	ContributorID       *uuid.UUID
	ContributorUsername string
	ImageKey            string
	IdempotencyKey      *uuid.UUID
	RequestHash         []byte
	Caption             *string
	ObservedAt          time.Time
	IsOriginal          bool
}

func (q *Queries) CreatePinPhoto(ctx context.Context, photo PinPhoto) error {
	return q.g.CreatePinPhoto(ctx, dbgen.CreatePinPhotoParams{
		ID: pgUUID(photo.ID), PinID: pgUUID(photo.PinID),
		ContributorID:       pgUUIDPtr(photo.ContributorID),
		ContributorUsername: photo.ContributorUsername,
		ImageKey:            photo.ImageKey, IdempotencyKey: pgUUIDPtr(photo.IdempotencyKey),
		RequestHash: photo.RequestHash,
		Caption:     pgText(photo.Caption),
		ObservedAt:  pgTZ(&photo.ObservedAt), IsOriginal: photo.IsOriginal,
	})
}

func (q *Queries) ListPinPhotos(ctx context.Context, pinID uuid.UUID) ([]PinPhoto, error) {
	rows, err := q.g.ListPinPhotos(ctx, pgUUID(pinID))
	if err != nil {
		return nil, err
	}
	photos := make([]PinPhoto, 0, len(rows))
	for _, row := range rows {
		var contributorID *uuid.UUID
		if row.ContributorID.Valid {
			id := goUUID(row.ContributorID)
			contributorID = &id
		}
		photos = append(photos, PinPhoto{
			ID: goUUID(row.ID), PinID: goUUID(row.PinID),
			ContributorID:       contributorID,
			ContributorUsername: row.ContributorUsername, ImageKey: row.ImageKey,
			IdempotencyKey: goUUIDPtr(row.IdempotencyKey),
			RequestHash:    row.RequestHash,
			Caption:        goText(row.Caption), ObservedAt: row.ObservedAt.Time,
			IsOriginal: row.IsOriginal,
		})
	}
	return photos, nil
}

func (q *Queries) GetPinPhotoByIdempotencyKey(ctx context.Context, contributorID, key uuid.UUID) (*PinPhoto, error) {
	row, err := q.g.GetPinPhotoByIdempotencyKey(ctx, dbgen.GetPinPhotoByIdempotencyKeyParams{
		ContributorID: pgUUID(contributorID), IdempotencyKey: pgUUID(key),
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var photoContributorID *uuid.UUID
	if row.ContributorID.Valid {
		id := goUUID(row.ContributorID)
		photoContributorID = &id
	}
	photo := PinPhoto{
		ID: goUUID(row.ID), PinID: goUUID(row.PinID),
		ContributorID:       photoContributorID,
		ContributorUsername: row.ContributorUsername, ImageKey: row.ImageKey,
		IdempotencyKey: goUUIDPtr(row.IdempotencyKey),
		RequestHash:    row.RequestHash,
		Caption:        goText(row.Caption), ObservedAt: row.ObservedAt.Time,
		IsOriginal: row.IsOriginal,
	}
	return &photo, nil
}

func (q *Queries) ListPinPhotoKeys(ctx context.Context, pinID uuid.UUID) ([]string, error) {
	return q.g.ListPinPhotoKeys(ctx, pgUUID(pinID))
}

func (q *Queries) EnqueueObjectCleanup(ctx context.Context, objectKeys []string) error {
	if len(objectKeys) == 0 {
		return nil
	}
	return q.g.EnqueueObjectCleanup(ctx, objectKeys)
}

func (q *Queries) StageObjectCleanup(ctx context.Context, objectKey string) error {
	return q.g.StageObjectCleanup(ctx, objectKey)
}

func (q *Queries) MarkObjectCleanupReady(ctx context.Context, objectKey string) error {
	return q.g.MarkObjectCleanupReady(ctx, objectKey)
}

func (q *Queries) RescheduleObjectCleanup(ctx context.Context, objectKey string) error {
	return q.g.RescheduleObjectCleanup(ctx, objectKey)
}

func (q *Queries) LockStagedObjectCleanup(ctx context.Context, objectKey string) (bool, error) {
	_, err := q.g.LockStagedObjectCleanup(ctx, objectKey)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (q *Queries) ClaimPendingObjectCleanup(ctx context.Context) (string, bool, error) {
	key, err := q.g.ClaimPendingObjectCleanup(ctx)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return key, true, nil
}

func (q *Queries) DeletePendingObjectCleanup(ctx context.Context, objectKey string) error {
	return q.g.DeletePendingObjectCleanup(ctx, objectKey)
}

func (q *Queries) TouchPinForPhoto(ctx context.Context, pinID uuid.UUID) (bool, error) {
	rows, err := q.g.TouchPinForPhoto(ctx, pgUUID(pinID))
	return rows > 0, err
}

func (q *Queries) GetPinByID(ctx context.Context, id uuid.UUID) (*Pin, error) {
	row, err := q.g.GetPinByID(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return pinFromRow(row), nil
}

func (q *Queries) PinExistsForUserAt(ctx context.Context, userID uuid.UUID, lat, lng float64, creation time.Time) (bool, error) {
	return q.g.PinExistsForUserAt(ctx, dbgen.PinExistsForUserAtParams{
		CreatorID:    pgUUID(userID),
		Latitude:     pgtype.Float8{Float64: lat, Valid: true},
		Longitude:    pgtype.Float8{Float64: lng, Valid: true},
		CreationDate: pgTZ(&creation),
	})
}

func (q *Queries) SoftDeletePin(ctx context.Context, id uuid.UUID) error {
	return q.g.SoftDeletePin(ctx, pgUUID(id))
}

func (q *Queries) HardDeletePin(ctx context.Context, id uuid.UUID) error {
	return q.g.HardDeletePin(ctx, pgUUID(id))
}

func (q *Queries) ListUserPinIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	rs, err := q.g.ListUserPinIDs(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, len(rs))
	for i, r := range rs {
		out[i] = goUUID(r)
	}
	return out, nil
}

func (q *Queries) ListGroupPinIDs(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rs, err := q.g.ListGroupPinIDs(ctx, pgUUID(groupID))
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, len(rs))
	for i, r := range rs {
		out[i] = goUUID(r)
	}
	return out, nil
}

func (q *Queries) ListUpdatedPinsForGroups(ctx context.Context, groupIDs []uuid.UUID, updatedAfter *time.Time) ([]Pin, error) {
	ids := make([]pgtype.UUID, len(groupIDs))
	for i, g := range groupIDs {
		ids[i] = pgUUID(g)
	}
	rs, err := q.g.ListUpdatedPinsForGroups(ctx, dbgen.ListUpdatedPinsForGroupsParams{
		GroupIds: ids, UpdatedAfter: pgTZ(updatedAfter),
	})
	if err != nil {
		return nil, err
	}
	out := make([]Pin, 0, len(rs))
	for _, r := range rs {
		var sp *uuid.UUID
		if r.StateProvinceID.Valid {
			u := goUUID(r.StateProvinceID)
			sp = &u
		}
		out = append(out, Pin{
			ID: goUUID(r.ID), Latitude: r.Latitude.Float64, Longitude: r.Longitude.Float64,
			CreationDate: goTZ(r.CreationDate), UpdateDate: goTZ(r.UpdateDate),
			Title: goText(r.Title), Description: goText(r.Description), CreatorID: goUUID(r.CreatorID),
			GroupID: goUUID(r.GroupID), StateProvinceID: sp,
			IsGone: r.IsGone,
		})
	}
	return out, nil
}

type PinSearch struct {
	CallerID           uuid.UUID
	IDs                []uuid.UUID
	GroupID            *uuid.UUID
	CreatorID          *uuid.UUID
	UpdatedAfter       *time.Time
	BeforeCreationDate *time.Time
	BeforeID           *uuid.UUID
	Limit              int32
	Offset             int32
}

type NearbyPin struct {
	Pin            Pin
	GroupName      string
	DistanceMeters int32
}

func (q *Queries) SearchPins(ctx context.Context, s PinSearch) ([]Pin, error) {
	ids := make([]pgtype.UUID, len(s.IDs))
	for i, id := range s.IDs {
		ids[i] = pgUUID(id)
	}
	limit := s.Limit
	if limit <= 0 {
		limit = 1<<31 - 1
	}
	rows, err := q.g.SearchPins(ctx, dbgen.SearchPinsParams{
		CallerID:           pgUUID(s.CallerID),
		Ids:                ids,
		GroupID:            pgUUIDPtr(s.GroupID),
		CreatorID:          pgUUIDPtr(s.CreatorID),
		UpdatedAfter:       pgTZ(s.UpdatedAfter),
		BeforeCreationDate: pgTZ(s.BeforeCreationDate),
		BeforeID:           pgUUIDPtr(s.BeforeID),
		Lim:                limit,
		Off:                s.Offset,
	})
	if err != nil {
		return nil, err
	}
	out := make([]Pin, 0, len(rows))
	for _, r := range rows {
		var boundary *uuid.UUID
		if r.StateProvinceID.Valid {
			id := goUUID(r.StateProvinceID)
			boundary = &id
		}
		out = append(out, Pin{
			ID: goUUID(r.ID), Latitude: r.Latitude.Float64, Longitude: r.Longitude.Float64,
			CreationDate: goTZ(r.CreationDate), UpdateDate: goTZ(r.UpdateDate),
			Title: goText(r.Title), Description: goText(r.Description), CreatorID: goUUID(r.CreatorID),
			GroupID: goUUID(r.GroupID), StateProvinceID: boundary,
			IsGone: r.IsGone,
		})
	}
	return out, nil
}

func (q *Queries) FindNearbyPins(ctx context.Context, callerID uuid.UUID, latitude, longitude float64, radiusMeters int32, limit int32) ([]NearbyPin, error) {
	if limit <= 0 || limit > 10 {
		limit = 10
	}
	rows, err := q.g.FindNearbyPins(ctx, dbgen.FindNearbyPinsParams{
		Longitude: longitude, Latitude: latitude, RadiusMeters: float64(radiusMeters),
		CallerID: pgUUID(callerID), Lim: limit,
	})
	if err != nil {
		return nil, err
	}
	out := make([]NearbyPin, 0, len(rows))
	for _, r := range rows {
		var boundary *uuid.UUID
		if r.StateProvinceID.Valid {
			id := goUUID(r.StateProvinceID)
			boundary = &id
		}
		out = append(out, NearbyPin{
			Pin: Pin{
				ID: goUUID(r.ID), Latitude: r.Latitude.Float64, Longitude: r.Longitude.Float64,
				CreationDate: goTZ(r.CreationDate), UpdateDate: goTZ(r.UpdateDate),
				Description: goText(r.Description), CreatorID: goUUID(r.CreatorID),
				GroupID: goUUID(r.GroupID), StateProvinceID: boundary, IsGone: r.IsGone,
			},
			GroupName: r.GroupName, DistanceMeters: r.DistanceMeters,
		})
	}
	return out, nil
}

func (q *Queries) ListDeletedPinsAfter(ctx context.Context, after time.Time) ([]uuid.UUID, error) {
	rs, err := q.g.ListDeletedPinsAfter(ctx, pgTZ(&after))
	if err != nil {
		return nil, err
	}
	out := make([]uuid.UUID, len(rs))
	for i, r := range rs {
		out[i] = goUUID(r)
	}
	return out, nil
}

func (q *Queries) FindBoundaryForPoint(ctx context.Context, lat, lng float64) (*uuid.UUID, error) {
	row, err := q.g.FindBoundaryForPoint(ctx, dbgen.FindBoundaryForPointParams{
		StPoint: lng, StPoint_2: lat,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if !row.Valid {
		return nil, nil
	}
	u := goUUID(row)
	return &u, nil
}

// ---- Likes ----

type UserLikedPin struct {
	PinID           uuid.UUID
	LikeAll         bool
	LikeLocation    bool
	LikePhotography bool
	LikeArt         bool
}

type LikeFlags struct {
	LikeAll, LikeLocation, LikePhotography, LikeArt bool
}

func (q *Queries) GetLikeByUserAndPin(ctx context.Context, userID, pinID uuid.UUID) (*LikeFlags, error) {
	row, err := q.g.GetLikeByUserAndPin(ctx, dbgen.GetLikeByUserAndPinParams{UserID: pgUUID(userID), PinID: pgUUID(pinID)})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &LikeFlags{LikeAll: row.LikeAll, LikeLocation: row.LikeLocation, LikePhotography: row.LikePhotography, LikeArt: row.LikeArt}, nil
}

func (q *Queries) UpsertLike(ctx context.Context, userID, pinID uuid.UUID, f LikeFlags) error {
	return q.g.UpsertLike(ctx, dbgen.UpsertLikeParams{
		ID: pgUUID(uuid.New()), PinID: pgUUID(pinID), UserID: pgUUID(userID),
		LikeAll: f.LikeAll, LikeLocation: f.LikeLocation,
		LikePhotography: f.LikePhotography, LikeArt: f.LikeArt,
	})
}

type LikeCounts struct {
	LikeAll, LikeLocation, LikePhotography, LikeArt int64
}

func (q *Queries) CountPinLikesByType(ctx context.Context, pinID uuid.UUID) (LikeCounts, error) {
	r, err := q.g.CountPinLikesByType(ctx, pgUUID(pinID))
	if err != nil {
		return LikeCounts{}, err
	}
	return LikeCounts{LikeAll: r.LikeAll, LikeLocation: r.LikeLocation, LikePhotography: r.LikePhotography, LikeArt: r.LikeArt}, nil
}

func (q *Queries) CountLikesForCreator(ctx context.Context, userID uuid.UUID) (LikeCounts, error) {
	r, err := q.g.CountLikesForCreator(ctx, pgUUID(userID))
	if err != nil {
		return LikeCounts{}, err
	}
	return LikeCounts{LikeAll: r.LikeAll, LikeLocation: r.LikeLocation, LikePhotography: r.LikePhotography, LikeArt: r.LikeArt}, nil
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

// ---- Seasons ----

func (q *Queries) GetMaxSeasonNumber(ctx context.Context) (int, error) {
	n, err := q.g.GetMaxSeasonNumber(ctx)
	return int(n), err
}

func (q *Queries) CreateSeason(ctx context.Context, seasonNumber, year, month int) (uuid.UUID, error) {
	id := uuid.New()
	row, err := q.g.CreateSeason(ctx, dbgen.CreateSeasonParams{
		ID:           pgUUID(id),
		SeasonNumber: int32(seasonNumber),
		Year:         int32(year),
		Month:        int32(month),
	})
	if err != nil {
		return uuid.Nil, err
	}
	return goUUID(row), nil
}

func (q *Queries) CreateUserSeason(ctx context.Context, userID, seasonID uuid.UUID, rank, pinCount int32) error {
	return q.g.CreateUserSeason(ctx, dbgen.CreateUserSeasonParams{
		ID:           pgUUID(uuid.New()),
		UserID:       pgUUID(userID),
		SeasonID:     pgUUID(seasonID),
		Rank:         rank,
		NumberOfPins: pinCount,
	})
}

func (q *Queries) CreateGroupSeason(ctx context.Context, groupID, seasonID uuid.UUID, rank, pinCount int32) error {
	return q.g.CreateGroupSeason(ctx, dbgen.CreateGroupSeasonParams{
		ID:           pgUUID(uuid.New()),
		GroupID:      pgUUID(groupID),
		SeasonID:     pgUUID(seasonID),
		Rank:         rank,
		NumberOfPins: pinCount,
	})
}

type SeasonItem struct {
	ID           uuid.UUID
	Rank         int32
	Points       int32
	SeasonID     uuid.UUID
	SeasonNumber int32
	Year         int32
	Month        int32
}

func (q *Queries) GetBestUserSeason(ctx context.Context, userID uuid.UUID) (*SeasonItem, error) {
	r, err := q.g.GetBestUserSeason(ctx, pgUUID(userID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &SeasonItem{ID: goUUID(r.ID), Rank: r.Rank, Points: r.NumberOfPins, SeasonID: goUUID(r.SeasonID), SeasonNumber: r.SeasonNumber, Year: r.Year, Month: r.Month}, nil
}

func (q *Queries) GetBestGroupSeason(ctx context.Context, groupID uuid.UUID) (*SeasonItem, error) {
	r, err := q.g.GetBestGroupSeason(ctx, pgUUID(groupID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &SeasonItem{ID: goUUID(r.ID), Rank: r.Rank, Points: r.NumberOfPins, SeasonID: goUUID(r.SeasonID), SeasonNumber: r.SeasonNumber, Year: r.Year, Month: r.Month}, nil
}

// ---- Notifications ----

type NotificationTarget struct {
	UserID        uuid.UUID
	FirebaseToken string
	PinCount      int32
}

func (q *Queries) FindUsersWithNewPins(ctx context.Context) ([]NotificationTarget, error) {
	rs, err := q.g.FindUsersWithNewPinsSinceLastActive(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]NotificationTarget, 0, len(rs))
	for _, r := range rs {
		out = append(out, NotificationTarget{
			UserID:        goUUID(r.ID),
			FirebaseToken: r.FirebaseToken.String,
			PinCount:      r.PinCount,
		})
	}
	return out, nil
}

// ---- Achievements ----

type UserAchievement struct {
	AchievementID int32
	Claimed       bool
}

func (q *Queries) GetSelectedUserAchievementID(ctx context.Context, userID uuid.UUID) (*int32, error) {
	id, err := q.g.GetSelectedUserAchievementID(ctx, pgUUID(userID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	def, ok := achievementDefinition(id)
	if !ok {
		if err := q.g.ReconcileUserAchievementClaim(ctx, dbgen.ReconcileUserAchievementClaimParams{
			ID: pgUUID(userID), AchievementID: id,
		}); err != nil {
			return nil, err
		}
		return nil, nil
	}
	current, err := q.runAchievementQuery(ctx, def, userID)
	if err != nil {
		return nil, err
	}
	if current < int(def.Threshold) {
		if err := q.g.ReconcileUserAchievementClaim(ctx, dbgen.ReconcileUserAchievementClaimParams{
			ID: pgUUID(userID), AchievementID: id,
		}); err != nil {
			return nil, err
		}
		return nil, nil
	}
	return &id, nil
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
	def, ok := achievementDefinition(achievementID)
	if !ok {
		return apperrors.ErrNotFound
	}
	_, err := q.g.ClaimUserAchievementAndAwardXP(ctx, dbgen.ClaimUserAchievementAndAwardXPParams{
		ID:                pgUUID(uuid.New()),
		UserID:            pgUUID(userID),
		AchievementID:     achievementID,
		XpAwarded:         def.RewardXP,
		DefinitionVersion: def.DefinitionVersion,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return apperrors.ErrConflict
	}
	return err
}

func (q *Queries) SetUserSelectedBatch(ctx context.Context, userID, achievementRowID uuid.UUID) error {
	return q.g.SetUserSelectedBatch(ctx, dbgen.SetUserSelectedBatchParams{
		ID: pgUUID(userID), SelectedBatch: pgUUID(achievementRowID),
	})
}

func (q *Queries) GetUserAchievementRow(ctx context.Context, userID uuid.UUID, achievementID int32) (*uuid.UUID, error) {
	row, err := q.g.GetUserAchievement(ctx, dbgen.GetUserAchievementParams{
		UserID: pgUUID(userID), AchievementID: achievementID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	id := goUUID(row.ID)
	return &id, nil
}

func (q *Queries) GetUserAchievementSelection(ctx context.Context, userID uuid.UUID, achievementID int32) (*uuid.UUID, bool, error) {
	row, err := q.g.GetUserAchievement(ctx, dbgen.GetUserAchievementParams{
		UserID: pgUUID(userID), AchievementID: achievementID,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	id := goUUID(row.ID)
	return &id, row.Claimed, nil
}
