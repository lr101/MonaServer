create table if not exists delete_log
(
    deleted_entity_type                    smallint not null,
    deleted_entity_id                      uuid not null,
    creation_date timestamp with time zone not null,
    constraint delete_log_key primary key (deleted_entity_type, deleted_entity_id)
);

ALTER TABLE groups ALTER COLUMN update_date TYPE TIMESTAMP WITH TIME ZONE USING update_date AT TIME ZONE 'UTC';
ALTER TABLE groups ALTER COLUMN creation_date TYPE TIMESTAMP WITH TIME ZONE USING creation_date AT TIME ZONE 'UTC';

ALTER TABLE pins ALTER COLUMN update_date TYPE TIMESTAMP WITH TIME ZONE USING update_date AT TIME ZONE 'UTC';
ALTER TABLE pins ALTER COLUMN creation_date TYPE TIMESTAMP WITH TIME ZONE USING creation_date AT TIME ZONE 'UTC';

ALTER TABLE users ALTER COLUMN update_date TYPE TIMESTAMP WITH TIME ZONE USING update_date AT TIME ZONE 'UTC';
ALTER TABLE users ALTER COLUMN creation_date TYPE TIMESTAMP WITH TIME ZONE USING creation_date AT TIME ZONE 'UTC';

ALTER TABLE refresh_token ALTER COLUMN update_date TYPE TIMESTAMP WITH TIME ZONE USING update_date AT TIME ZONE 'UTC';
ALTER TABLE refresh_token ALTER COLUMN creation_date TYPE TIMESTAMP WITH TIME ZONE USING creation_date AT TIME ZONE 'UTC';

create index if not exists idx_deleted_creation_date on delete_log(creation_date);
create index if not exists idx_groups_updated_date on groups(update_date);
create index if not exists idx_pins_updated_date on pins(update_date);
create index if not exists idx_users_updated_date on users(update_date);
