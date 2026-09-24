package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

const adminPasswordRecoveryLinkTTL = 10 * time.Minute

// AdminPasswordRecovery sends a verified account address a restricted
// recovery link after authorizing and auditing the requesting admin actor.
// It does not disable the current password; the account owner changes it by
// completing the one-use recovery flow.
type AdminPasswordRecovery struct {
	q    *db.Queries
	mail *Email
	now  func() time.Time
}

func NewAdminPasswordRecovery(q *db.Queries, mail *Email) *AdminPasswordRecovery {
	return &AdminPasswordRecovery{q: q, mail: mail, now: time.Now}
}

func (s *AdminPasswordRecovery) SetClock(now func() time.Time) {
	if s != nil && now != nil {
		s.now = now
	}
}

func (s *AdminPasswordRecovery) SendPasswordResetLink(ctx context.Context, actor AdminActor, accountID uuid.UUID) error {
	if s == nil || s.q == nil {
		return ErrAdminRepositoryAbsent
	}
	if s.mail == nil {
		return ErrEmailDeliveryUnavailable
	}
	if !actor.Valid() {
		return ErrAudienceUnauthorized
	}
	if !actor.Can("security.recovery_resend") {
		return ErrAudienceForbidden
	}
	if accountID == uuid.Nil {
		return apperrors.ErrBadRequest
	}

	now := time.Now()
	if s.now != nil {
		now = s.now()
	}
	if now.IsZero() {
		now = time.Now()
	}
	return s.q.InTx(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, accountID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			return ErrUserNotFound
		}
		if !canUseRecoveryAction(state) {
			return ErrUserEmailUnavailable
		}
		email, err := canonicalVerifiedEmail(ctx, tx, state)
		if err != nil {
			return err
		}
		if email == nil {
			return ErrUserEmailUnavailable
		}
		user, err := tx.GetUserByID(ctx, accountID)
		if err != nil {
			return err
		}
		if user == nil {
			return ErrUserNotFound
		}

		link, err := randomOpaqueToken()
		if err != nil {
			return ErrEmailDeliveryUnavailable
		}
		if err := tx.SetUserResetPasswordUrl(ctx, accountID, link, now.Add(adminPasswordRecoveryLinkTTL)); err != nil {
			return err
		}
		actorID := actor.ID
		targetID := accountID
		reason := "admin requested password recovery"
		outcome := "sent"
		if err := tx.CreateAuditEvent(ctx, db.AuditEventParams{
			ID: uuid.New(), ActorID: &actorID, TargetAccountID: &targetID,
			Action: "password_reset_email_requested", Reason: &reason, Outcome: &outcome,
		}); err != nil {
			return err
		}
		return s.mail.SendPasswordRecovery(ctx, user.Username, *email, link)
	})
}
