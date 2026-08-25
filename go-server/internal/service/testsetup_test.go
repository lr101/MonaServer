package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/token"
)

func setupPool(t *testing.T) (*pgxpool.Pool, *db.Queries) {
	t.Helper()
	dsn := testDSN(t)
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users, groups, pins, likes, members, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	return pool, db.New(pool)
}

func setupServices(t *testing.T) (*db.Queries, *Auth, *User, *Like, *Pin, *Group, *Member, *Ranking, *Guard) {
	t.Helper()
	_, q := setupPool(t)
	tok := token.NewHelper("test-secret", time.Minute)
	cfg := &config.Config{MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour}
	authSvc := NewAuth(q, tok, cfg)
	userSvc := NewUser(q, nil, tok, authSvc, nil)
	likeSvc := NewLike(q)
	pinSvc := NewPin(q, nil)
	groupSvc := NewGroup(q, nil, userSvc)
	memberSvc := NewMember(q, nil, groupSvc)
	rankSvc := NewRanking(q)
	guardSvc := NewGuard(q)
	return q, authSvc, userSvc, likeSvc, pinSvc, groupSvc, memberSvc, rankSvc, guardSvc
}

// createTestUser signs up and returns the user ID.
func createTestUser(t *testing.T, auth *Auth, username string) uuid.UUID {
	t.Helper()
	pair, err := auth.Signup(context.Background(), username, "password123", nil)
	if err != nil {
		t.Fatalf("signup %q: %v", username, err)
	}
	return pair.UserID
}

// createTestGroup creates a public group and returns its ID.
func createTestGroup(t *testing.T, group *Group, adminID uuid.UUID, name string) uuid.UUID {
	t.Helper()
	g, err := group.Create(context.Background(), CreateGroupInput{
		Name:       name,
		Visibility: 0,
		GroupAdmin: adminID,
	})
	if err != nil {
		t.Fatalf("create group %q: %v", name, err)
	}
	return g.ID
}

// createTestPin creates a pin and returns its ID.
func createTestPin(t *testing.T, pin *Pin, userID, groupID uuid.UUID) uuid.UUID {
	t.Helper()
	dto, err := pin.Create(context.Background(), CreatePinInput{
		Latitude:     48.1,
		Longitude:    11.6,
		CreationDate: time.Now(),
		UserID:       userID,
		GroupID:      groupID,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	return dto.ID
}
