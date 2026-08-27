package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/image"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/token"
)

// UsernameChangeTimeout mirrors UserServiceImpl.USERNAME_CHANGE_TIMEOUT.
const UsernameChangeTimeout = 14 * 24 * time.Hour

// UserUpdateInput captures the writable fields of UserUpdateDto.
type UserUpdateInput struct {
	Description    *string
	Email          *string
	Image          []byte
	MessagingToken *string
	Password       *string
	SelectedBatch  *int32
	Username       *string
}

// UserUpdateResult mirrors UserUpdateResponseDto.
type UserUpdateResult struct {
	UserTokenDto      *TokenPair `json:"userTokenDto,omitempty"`
	UserInfoDto       *UserInfo  `json:"userInfoDto"`
	ProfileImage      *string    `json:"profileImage,omitempty"`
	ProfileImageSmall *string    `json:"profileImageSmall,omitempty"`
}

// UserInfo mirrors UserInfoDto.
type UserInfo struct {
	ID                    uuid.UUID      `json:"id"`
	Username              string         `json:"username"`
	Email                 *string        `json:"email,omitempty"`
	Description           *string        `json:"description,omitempty"`
	Xp                    int64          `json:"xp"`
	ProfilePictureExists  bool           `json:"profilePictureExists"`
	EmailConfirmed        bool           `json:"emailConfirmed"`
	SelectedBatch         *int32         `json:"selectedBatch,omitempty"`
	BestSeason            *db.SeasonItem `json:"bestSeason,omitempty"`
	IsMessagingRegistered *bool          `json:"isMessagingRegistered,omitempty"`
}

// ToPublicUserInfo hides sensitive fields for the public GET /users/{id} response.
func ToPublicUserInfo(u *db.User) *UserInfo {
	return &UserInfo{
		ID:                   u.ID,
		Username:             u.Username,
		Description:          u.Description,
		Xp:                   u.XP,
		ProfilePictureExists: u.ProfilePictureExists,
	}
}

func toUserInfo(u *db.User) *UserInfo {
	return &UserInfo{
		ID:                   u.ID,
		Username:             u.Username,
		Email:                u.Email,
		Description:          u.Description,
		Xp:                   u.XP,
		ProfilePictureExists: u.ProfilePictureExists,
		EmailConfirmed:       u.EmailConfirmed,
	}
}

// User service — ports UserServiceImpl.
type User struct {
	q    *db.Queries
	obj  *Object
	tok  *token.Helper
	auth *Auth
	mail *Email
}

func NewUser(q *db.Queries, obj *Object, tok *token.Helper, auth *Auth, mail *Email) *User {
	return &User{q: q, obj: obj, tok: tok, auth: auth, mail: mail}
}

func (s *User) Get(ctx context.Context, id uuid.UUID) (*db.User, error) {
	u, err := s.q.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, apperrors.ErrNotFound
	}
	return u, nil
}

// Delete mirrors UserServiceImpl.deleteUser: verifies code + expiration and physically deletes the account.
func (s *User) Delete(ctx context.Context, id uuid.UUID, code int) error {
	u, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	if u.Code == nil || u.CodeExpiration == nil {
		return apperrors.ErrNotFound
	}
	if *u.Code != itoaCode(code) {
		return apperrors.ErrNotFound
	}
	if time.Now().After(*u.CodeExpiration) {
		return apperrors.New(400, "code expired")
	}
	groupIDs, err := s.q.ListAdminGroupIDs(ctx, id)
	if err != nil {
		return err
	}
	pinIDs, err := s.q.ListPinIDsRemovedWithUser(ctx, id)
	if err != nil {
		return err
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		for _, pinID := range pinIDs {
			if err := q.LogDeletion(ctx, db.DeletedEntityPin, pinID); err != nil {
				return err
			}
		}
		for _, groupID := range groupIDs {
			if err := q.LogDeletion(ctx, db.DeletedEntityGroup, groupID); err != nil {
				return err
			}
		}
		if err := q.LogDeletion(ctx, db.DeletedEntityUser, id); err != nil {
			return err
		}
		return q.HardDeleteUser(ctx, id)
	}); err != nil {
		return err
	}
	if s.obj != nil {
		for _, pinID := range pinIDs {
			_ = s.obj.Remove(ctx, PinKey(pinID))
		}
		for _, groupID := range groupIDs {
			_ = s.obj.Remove(ctx, GroupPinKey(groupID))
			_ = s.obj.Remove(ctx, GroupProfileKey(groupID, false))
			_ = s.obj.Remove(ctx, GroupProfileKey(groupID, true))
		}
		_ = s.obj.Remove(ctx, UserProfileKey(id, false))
		_ = s.obj.Remove(ctx, UserProfileKey(id, true))
	}
	return nil
}

// ProfileImageURL returns a presigned URL or nil if no image / no object store.
func (s *User) ProfileImageURL(ctx context.Context, id uuid.UUID, small bool) (*string, error) {
	u, err := s.q.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, apperrors.ErrNotFound
	}
	if !u.ProfilePictureExists || s.obj == nil {
		return nil, nil
	}
	url, err := s.obj.PresignedGet(ctx, UserProfileKey(id, small))
	if err != nil {
		return nil, err
	}
	if url == "" {
		return nil, nil
	}
	return &url, nil
}

// Update mirrors UserServiceImpl.updateUser.
func (s *User) Update(ctx context.Context, id uuid.UUID, in UserUpdateInput) (*UserUpdateResult, error) {
	var result *UserUpdateResult
	err := s.q.InTx(ctx, func(q *db.Queries) error {
		txService := *s
		txService.q = q
		if s.auth != nil {
			txAuth := *s.auth
			txAuth.q = q
			txService.auth = &txAuth
		}
		var err error
		result, err = txService.update(ctx, id, in)
		return err
	})
	return result, err
}

func (s *User) update(ctx context.Context, id uuid.UUID, in UserUpdateInput) (*UserUpdateResult, error) {
	u, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}

	var tokenResp *TokenPair
	var profileImg, profileImgSmall *string

	if len(in.Image) > 0 {
		if s.obj == nil {
			return nil, apperrors.ErrUnavailable
		}
		large, err := image.CompressProfileJPEG(in.Image, 500)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
		small, err := image.CompressProfileJPEG(in.Image, 100)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
		if err := s.obj.Put(ctx, UserProfileKey(id, false), large, "image/jpeg"); err != nil {
			return nil, err
		}
		if err := s.obj.Put(ctx, UserProfileKey(id, true), small, "image/jpeg"); err != nil {
			return nil, err
		}
		if err := s.q.SetUserProfilePictureExists(ctx, id, true); err != nil {
			return nil, err
		}
		u.ProfilePictureExists = true
		largeURL, _ := s.obj.PresignedGet(ctx, UserProfileKey(id, false))
		smallURL, _ := s.obj.PresignedGet(ctx, UserProfileKey(id, true))
		profileImg = strPtr(largeURL)
		profileImgSmall = strPtr(smallURL)
	}

	if in.Email != nil {
		if !u.EmailConfirmed {
			return nil, apperrors.New(403, "email is not confirmed")
		}
		confirmUrl := randomURL()
		if err := s.q.UpdateUserEmail(ctx, id, in.Email, &confirmUrl); err != nil {
			return nil, err
		}
		if s.mail != nil {
			if err := s.mail.SendEmailConfirmation(ctx, u.Username, *in.Email, confirmUrl); err != nil {
				return nil, err
			}
		}
		u.Email = in.Email
		u.EmailConfirmed = false
	}

	if in.Password != nil {
		hash, err := password.Hash(*in.Password)
		if err != nil {
			return nil, err
		}
		if err := s.q.UpdateUserPassword(ctx, id, hash); err != nil {
			return nil, err
		}
		if err := s.q.InvalidateUserTokens(ctx, id); err != nil {
			return nil, err
		}
		pair, err := s.auth.issueTokens(ctx, id)
		if err != nil {
			return nil, err
		}
		tokenResp = pair
	}

	if in.Description != nil {
		if err := s.q.UpdateUserDescription(ctx, id, in.Description); err != nil {
			return nil, err
		}
		u.Description = in.Description
	}

	if in.Username != nil {
		if u.LastUsernameUpdate != nil && time.Since(*u.LastUsernameUpdate) < UsernameChangeTimeout {
			return nil, apperrors.New(400, "username can only be changed once every 14 days")
		}
		existing, err := s.q.GetUserByUsername(ctx, *in.Username)
		if err != nil {
			return nil, err
		}
		if existing != nil && existing.ID != id {
			return nil, apperrors.ErrConflict
		}
		if err := s.q.UpdateUserUsername(ctx, id, *in.Username); err != nil {
			return nil, err
		}
		u.Username = *in.Username
	}

	if in.MessagingToken != nil {
		if err := s.q.UpdateUserFirebaseToken(ctx, id, in.MessagingToken); err != nil {
			return nil, err
		}
		u.FirebaseToken = in.MessagingToken
	}

	if in.SelectedBatch != nil {
		rowID, claimed, err := s.q.GetUserAchievementSelection(ctx, id, *in.SelectedBatch)
		if err != nil {
			return nil, err
		}
		if rowID == nil {
			return nil, apperrors.ErrNotFound
		}
		if claimed {
			if err := s.q.SetUserSelectedBatch(ctx, id, *rowID); err != nil {
				return nil, err
			}
			u.SelectedBatch = rowID
		}
	}
	selectedBatch, err := s.q.GetSelectedUserAchievementID(ctx, id)
	if err != nil {
		return nil, err
	}
	bestSeason, err := s.q.GetBestUserSeason(ctx, id)
	if err != nil {
		return nil, err
	}
	messagingRegistered := u.FirebaseToken != nil
	info := toUserInfo(u)
	info.SelectedBatch = selectedBatch
	info.BestSeason = bestSeason
	info.IsMessagingRegistered = &messagingRegistered

	return &UserUpdateResult{
		UserTokenDto:      tokenResp,
		UserInfoDto:       info,
		ProfileImage:      profileImg,
		ProfileImageSmall: profileImgSmall,
	}, nil
}

// Achievements returns the user's achievement progress.
func (s *User) Achievements(ctx context.Context, id uuid.UUID) ([]db.UserAchievement, error) {
	return s.q.ListUserAchievements(ctx, id)
}

// ClaimAchievement marks a user achievement as claimed.
func (s *User) ClaimAchievement(ctx context.Context, id uuid.UUID, achievementID int32) error {
	return s.q.ClaimUserAchievement(ctx, id, achievementID)
}

// LikedPins lists pins the user has liked.
func (s *User) LikedPins(ctx context.Context, id uuid.UUID) ([]db.UserLikedPin, error) {
	return s.q.ListUserLikedPins(ctx, id)
}

// ---- helpers ----

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func itoaCode(n int) string {
	if n < 0 {
		n = -n
	}
	// 6-digit zero-padded code like the Kotlin impl.
	b := [6]byte{'0', '0', '0', '0', '0', '0'}
	i := len(b) - 1
	for n > 0 && i >= 0 {
		b[i] = byte('0' + n%10)
		n /= 10
		i--
	}
	return string(b[:])
}

// randomURL is a short opaque slug used for recovery/confirmation URLs.
func randomURL() string {
	return uuid.NewString()
}

var _ = errors.New // keep errors import for future wrapping
