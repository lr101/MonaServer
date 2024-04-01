create table if not exists  users
(
    id                    uuid                  not null
        constraint t_users_pkey
            primary key,
    username              varchar(255)
        constraint unique_username_constraint
            unique,
    email                 varchar(255),
    password              varchar(255),
    profile_picture       oid,
    profile_picture_small bytea,
    update_date           timestamp(6),
    creation_date         timestamp(6),
    reset_password_url    varchar(255)
        constraint unique_reset_url_constraint
            unique,
    token                 varchar(500)
        constraint unique_token_constraint
            unique,
    code                  varchar(6),
    is_deleted            boolean default false not null
);

create table if not exists  groups
(
    id            uuid                  not null
        constraint t_groups_pkey
            primary key,
    description   varchar(255),
    invite_url    varchar(255)
        constraint invite_constraint
            unique,
    name          varchar(255)
        constraint name_constraint
            unique,
    pin_image     bytea                 ,
    profile_image oid                   ,
    visibility    integer               ,
    link          varchar(255),
    creation_date timestamp(6),
    update_date   timestamp(6),
    is_deleted    boolean default false not null,
    admin_id      uuid
        constraint fk_groups_group_admin
            references users
            on update cascade on delete cascade
);

create table if not exists  members
(
    group_id uuid not null
        constraint fk_members_group_id
            references groups
            on delete cascade,
    user_id  uuid
        constraint fk_members_username
            references users
            on update cascade on delete cascade
);

create table if not exists  pins
(
    id            uuid                  not null
        constraint t_pins_pkey
            primary key,
    creation_date timestamp(6)          ,
    latitude      double precision      ,
    longitude     double precision      ,
    update_date   timestamp(6),
    image         oid,
    is_deleted    boolean default false not null,
    creator_id    uuid
        constraint fk_pins_creation_user
            references users
            on update cascade on delete cascade
);

create table if not exists  groups_pins
(
    group_id uuid not null
        constraint fk_group_pin_group_id
            references groups
            on delete cascade,
    pin_id   uuid not null
        constraint fk_group_in_pin_id
            references pins
            on delete cascade
);

