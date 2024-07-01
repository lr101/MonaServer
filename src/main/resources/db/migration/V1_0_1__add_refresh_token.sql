create table if not exists  refresh_token
(
    id                    uuid                  not null
        constraint t_fresh_token_pkey
            primary key,
    update_date           timestamp(6),
    creation_date         timestamp(6),
    expiry_date            timestamp(6) not null ,
    token                 uuid constraint unique_token_constraint_refresh unique not null,
    user_id               uuid null
        constraint fk_refresh_token_user_id
            references users on update cascade on delete cascade
);

ALTER TABLE users DROP COLUMN IF EXISTS token;