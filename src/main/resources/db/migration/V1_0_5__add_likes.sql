create table if not exists likes
(
    id                           uuid not null primary key,
    pin_id                       uuid not null,
    user_id                      uuid not null,
    creation_date timestamp with time zone not null,
    update_date timestamp with time zone not null,
    like_all boolean default false not null,
    like_location boolean default false not null,
    like_photography boolean default false not null,
    like_art boolean default false not null,
    CONSTRAINT fk_likes_pin FOREIGN KEY (pin_id) REFERENCES pins(id),
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id)
);
