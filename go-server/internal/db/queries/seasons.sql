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

-- name: GetBestUserSeason :one
SELECT us.id, us.rank, us.number_of_pins,
       s.id AS season_id, s.season_number, s.year, s.month
FROM users_seasons us
JOIN seasons s ON s.id = us.season_id
WHERE us.user_id = $1
ORDER BY us.rank ASC, us.number_of_pins DESC, s.season_number DESC
LIMIT 1;

-- name: GetBestGroupSeason :one
SELECT gs.id, gs.rank, gs.number_of_pins,
       s.id AS season_id, s.season_number, s.year, s.month
FROM groups_seasons gs
JOIN seasons s ON s.id = gs.season_id
WHERE gs.group_id = $1
ORDER BY gs.rank ASC, gs.number_of_pins DESC, s.season_number DESC
LIMIT 1;
