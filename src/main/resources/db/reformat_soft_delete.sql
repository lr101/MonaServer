create table t_users
(
    id                    uuid not null primary key,
    username              varchar(255)
        constraint unique_username_constraint unique,
    email                 varchar(255),
    password              varchar(255),
    profile_picture       oid,
    profile_picture_small bytea,
    update_date   timestamp(6),
    creation_date timestamp(6),
        reset_password_url    varchar(255)
        constraint unique_reset_url_constraint unique,
    token                 varchar(500)
        constraint unique_token_constraint unique,
    code                  varchar(6),
    is_deleted            boolean default false not null
);

create table t_groups
(
    id    uuid not null primary key,
    description   varchar(255),
    invite_url    varchar(255)
        constraint invite_constraint
            unique,
    name          varchar(255)                           not null
        constraint name_constraint
            unique,
    pin_image     bytea                                  not null,
    profile_image oid                                    not null,
    visibility    integer                                not null,
    link          varchar(255),
    creation_date timestamp(6),
    update_date   timestamp(6),
    is_deleted    boolean                  default false not null,
    admin_id      uuid
        constraint fk_groups_group_admin
            references t_users
            on update cascade on delete cascade
);

create table t_members
(
    group_id  uuid not null
        constraint fk_members_group_id
            references t_groups
            on delete cascade,
    user_id uuid
        constraint fk_members_username
            references t_users
            on update cascade on delete cascade
);

create table t_pins
(
    id            uuid not null
        primary key,
    old_id bigint,
    creation_date timestamp  (6)                            not null,
    latitude      double precision                       not null,
    longitude     double precision                       not null,
    update_date   timestamp(6),
    image         oid,
    is_deleted    boolean                  default false not null,
    creator_id    uuid
        constraint fk_pins_creation_user
            references t_users
            on update cascade on delete cascade
);

create table t_groups_pins
(
    group_id uuid not null
        constraint fk_group_pin_group_id
            references t_groups
            on delete cascade,
    pin_id       uuid not null
        constraint fk_group_in_pin_id
            references t_pins
            on delete cascade
);

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

INSERT INTO t_users (
    id,
    username,
    email,
    password,
    profile_picture,
    profile_picture_small,
    reset_password_url,
    update_date,
    creation_date,
    token,
    code,
    is_deleted
)
SELECT
    uuid_generate_v4(),
    username,
    email,
    password,
    profile_picture,
    profile_picture_small,
    reset_password_url,
    current_timestamp,
    current_timestamp,
    token,
    code,
    false
FROM
    users;


INSERT INTO t_groups (id, description, invite_url, name, pin_image, profile_image, visibility, link, creation_date, update_date, is_deleted, admin_id)
SELECT
    uuid_generate_v4(), -- Assuming you're generating UUIDs for new records
    g.description,
    g.invite_url,
    g.name,
    g.pin_image,
    g.profile_image,
    g.visibility,
    g.link,
    current_timestamp,
    current_timestamp,
    false,
    t2.id
FROM
    groups g
        JOIN
    t_users t2 ON g.group_admin = t2.username;

INSERT INTO t_members(group_id, user_id)
    SELECT tg.id, u.id
FROM members m
    JOIN groups g on m.group_id = g.group_id
    JOIN t_groups tg on g.name = tg.name
    JOIN t_users u on m.username = u.username;

INSERT INTO t_pins(id, old_id,creation_date, latitude, longitude, update_date, is_deleted, creator_id,image)
    SELECT
        uuid_generate_v4(),
        p.id,
        p.creation_date,
        p.latitude,
        p.longitude,
        current_timestamp,
        false,
        u.id,
        m.image
    FROM pins p
        JOIN t_users u on p.creation_user = u.username
        JOIN monas m on m.pin = p.id;

INSERT INTO t_groups_pins(group_id, pin_id)
SELECT tg.id, p.id
FROM groups_pins gp
         JOIN groups g on gp.group_id = g.group_id
         JOIN t_groups tg on g.name = tg.name
         JOIN t_pins p on gp.id = p.old_id;

ALTER TABLE t_pins DROP old_id;

DROP TABLE groups;
DROP TABLE groups_pins;
DROP TABLE members;
DROP TABLE monas;
DROP TABLE pins;
DROP TABLE users;

ALTER TABLE t_groups RENAME TO groups;
ALTER TABLE t_groups_pins RENAME TO groups_pins;
ALTER TABLE t_members RENAME TO members;
ALTER TABLE t_users RENAME TO users;
ALTER TABLE t_pins RENAME TO pins;