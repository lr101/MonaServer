create table if not exists users
(
    username              varchar(255) not null
        primary key,
    email                 varchar(255),
    password              varchar(255),
    profile_picture       oid,
    profile_picture_small bytea,
    reset_password_url    varchar(255)
        constraint uk_kaanplsqmebuhfs8tlv07hf0r
            unique,
    token                 varchar(500)
        constraint uk_af44yue4uh61eqwe6jjyqwvla
            unique,
    code                  varchar(6)
);

create table if not exists groups
(
    group_id      integer      not null
        primary key,
    description   varchar(255),
    invite_url    varchar(255)
        constraint uk_1a5xrytbgj6o6lknck6fmfuwh
            unique,
    name          varchar(255) not null
        constraint uk_8mf0is8024pqmwjxgldfe54l7
            unique,
    pin_image     bytea        not null,
    profile_image oid          not null,
    visibility    integer      not null,
    group_admin   varchar(255) not null
        constraint fka9d16foh70dh031qaipyt53om
            references users,
    link          varchar(255),
    last_updated timestamp with time zone default current_timestamp
);

create table if not exists members
(
    group_id integer      not null
        constraint fk1jmeir47b7qcn2sd5m4txgfuw
            references groups
            on delete cascade,
    username varchar(255) not null
        constraint fkn0wccjg5nnc1fpme0tbskrqyk
            references users
            on update cascade on delete cascade,
    primary key (group_id, username)
);


create table if not exists pins
(
    id            integer          not null
        primary key,
    creation_date timestamp        not null,
    latitude      double precision not null,
    longitude     double precision not null,
    creation_user varchar(255)
        constraint fkcmfp4avd369iporoc0wul4wvf
            references users
            on update cascade on delete cascade,
    last_updated timestamp with time zone default current_timestamp
);

create table if not exists groups_pins
(
    group_id integer not null
        constraint fk2konlwk65hd76jr0nhbxm0xef
            references groups
            on delete cascade,
    id       integer not null
        constraint fkk30yjnc9woedfmvq8m30dk6n4
            references pins
            on delete cascade,
    primary key (group_id, id)
);


create table if not exists monas
(
    id    integer not null
        primary key,
    image oid     not null,
    pin   integer not null
        constraint fkb7adbn9x8bxhfarvx3nxvcxbn
            references pins
            on update cascade on delete cascade
);
