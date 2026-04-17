-- User and refresh-token queries.

-- name: GetUserByID :one
SELECT id, username, email, password, xp, description, profile_picture_exists,
       email_confirmed, failed_login_attempts, firebase_token,
       code, code_expiration, reset_password_url, reset_password_expiration,
       deletion_url, email_confirmation_url, last_username_update, selected_batch
FROM users
WHERE id = $1 AND is_deleted = FALSE;

-- name: GetUserByUsername :one
SELECT id, username, email, password, xp, description, profile_picture_exists,
       email_confirmed, failed_login_attempts, firebase_token,
       code, code_expiration, reset_password_url, reset_password_expiration,
       deletion_url, email_confirmation_url, last_username_update, selected_batch
FROM users
WHERE username = $1 AND is_deleted = FALSE;

-- name: GetUsernameByID :one
SELECT username FROM users WHERE id = $1 AND is_deleted = FALSE;

-- name: CreateUser :one
INSERT INTO users (id, username, password, email, creation_date, update_date)
VALUES ($1, $2, $3, $4, NOW(), NOW())
RETURNING id;

-- name: IncrementFailedLogin :exec
UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = $1;

-- name: ResetFailedLogin :exec
UPDATE users SET failed_login_attempts = 0 WHERE id = $1;

-- name: SoftDeleteUser :exec
UPDATE users SET is_deleted = TRUE WHERE id = $1;

-- name: UpdateUserDescription :exec
UPDATE users SET description = $2, update_date = NOW() WHERE id = $1;

-- name: UpdateUserFirebaseToken :exec
UPDATE users SET firebase_token = $2, update_date = NOW() WHERE id = $1;

-- name: UpdateUserUsername :exec
UPDATE users
SET username = $2, last_username_update = NOW(), update_date = NOW()
WHERE id = $1;

-- name: UpdateUserPassword :exec
UPDATE users
SET password = $2,
    reset_password_url = NULL,
    reset_password_expiration = NULL,
    failed_login_attempts = 0,
    update_date = NOW()
WHERE id = $1;

-- name: UpdateUserEmail :exec
UPDATE users
SET email = $2,
    code = NULL,
    code_expiration = NULL,
    email_confirmation_url = $3,
    email_confirmed = FALSE,
    update_date = NOW()
WHERE id = $1;

-- name: SetUserProfilePictureExists :exec
UPDATE users SET profile_picture_exists = $2, update_date = NOW() WHERE id = $1;

-- name: SetUserSelectedBatch :exec
UPDATE users SET selected_batch = $2, update_date = NOW() WHERE id = $1;

-- name: GetUserByIDAndCode :one
SELECT id FROM users
WHERE id = $1 AND code = $2 AND is_deleted = FALSE;

-- name: GetUserByResetPasswordUrl :one
SELECT id, username, email, reset_password_expiration
FROM users
WHERE reset_password_url = $1 AND is_deleted = FALSE;

-- name: GetUserByDeletionUrl :one
SELECT id, username, email, code_expiration
FROM users
WHERE deletion_url = $1 AND is_deleted = FALSE;

-- name: GetUserByEmailConfirmationUrl :one
SELECT id, username, email
FROM users
WHERE email_confirmation_url = $1 AND is_deleted = FALSE;

-- name: ConfirmUserEmail :exec
UPDATE users
SET email_confirmed = TRUE,
    email_confirmation_url = NULL,
    update_date = NOW()
WHERE id = $1;

-- name: SetUserRecoveryCode :exec
UPDATE users
SET code = $2, code_expiration = $3, update_date = NOW()
WHERE id = $1;

-- name: SetUserDeletionUrl :exec
UPDATE users
SET deletion_url = $2, code_expiration = $3, update_date = NOW()
WHERE id = $1;

-- name: SetUserResetPasswordUrl :exec
UPDATE users
SET reset_password_url = $2, reset_password_expiration = $3, update_date = NOW()
WHERE id = $1;

-- name: AddUserXp :exec
UPDATE users SET xp = xp + $2, update_date = NOW() WHERE id = $1;

-- Refresh tokens --

-- name: CreateRefreshToken :exec
INSERT INTO refresh_token (id, token, user_id, creation_date, update_date, last_active_date)
VALUES ($1, $2, $3, NOW(), NOW(), NOW());

-- name: FindRefreshToken :one
SELECT user_id FROM refresh_token WHERE token = $1;

-- name: TouchRefreshToken :exec
UPDATE refresh_token SET last_active_date = NOW() WHERE token = $1;

-- name: InvalidateUserTokens :exec
DELETE FROM refresh_token WHERE user_id = $1;

-- name: ListAllUserEmails :many
SELECT email FROM users WHERE is_deleted = FALSE AND email IS NOT NULL AND email_confirmed = TRUE;
