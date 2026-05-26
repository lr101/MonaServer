-- Season queries.

-- name: GetMaxSeasonNumber :one
SELECT COALESCE(MAX(season_number), 0)::int FROM seasons;

-- name: CreateSeason :one
INSERT INTO seasons (id, season_number, year, month, creation_date, update_date)
VALUES ($1, $2, $3, $4, NOW(), NOW())
RETURNING id;

-- name: CreateUserSeason :exec
INSERT INTO users_seasons (id, user_id, season_id, rank, number_of_pins, creation_date, update_date)
VALUES ($1, $2, $3, $4, $5, NOW(), NOW());

-- name: CreateGroupSeason :exec
INSERT INTO groups_seasons (id, group_id, season_id, rank, number_of_pins, creation_date, update_date)
VALUES ($1, $2, $3, $4, $5, NOW(), NOW());
