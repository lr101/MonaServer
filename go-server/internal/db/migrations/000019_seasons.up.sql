CREATE TABLE IF NOT EXISTS seasons
(
    id uuid not null primary key,
    season_number int not null unique,
    year int not null,
    month int not null,
    creation_date timestamp with time zone not null,
    update_date timestamp with time zone not null
);

CREATE TABLE IF NOT EXISTS users_seasons
(
    id uuid not null primary key,
    user_id uuid not null constraint fk_users_seasons_user_id references users(id) on delete cascade,
    season_id uuid not null constraint fk_users_seasons_season_id references seasons(id) on delete cascade,
    rank int not null,
    number_of_pins int not null,
    creation_date timestamp with time zone not null,
    update_date timestamp with time zone not null
);

CREATE TABLE IF NOT EXISTS groups_seasons
(
    id uuid not null primary key,
    group_id uuid not null constraint fk_users_seasons_group_id references groups(id) on delete cascade,
    season_id uuid not null constraint fk_users_seasons_season_id references seasons(id) on delete cascade,
    rank int not null,
    number_of_pins int not null,
    creation_date timestamp with time zone not null,
    update_date timestamp with time zone not null
);

