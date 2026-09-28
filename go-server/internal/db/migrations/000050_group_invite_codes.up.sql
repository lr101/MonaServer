DO $$
DECLARE
    target_group_id UUID;
    invite_code TEXT;
    random_value BIGINT;
    uuid_bytes BYTEA;
    digit INTEGER;
BEGIN
    FOR target_group_id IN
        SELECT id FROM groups WHERE invite_url IS NULL
    LOOP
        LOOP
            uuid_bytes := uuid_send(gen_random_uuid());
            random_value := (
                get_byte(uuid_bytes, 0)::BIGINT * 16777216 +
                get_byte(uuid_bytes, 1)::BIGINT * 65536 +
                get_byte(uuid_bytes, 2)::BIGINT * 256 +
                get_byte(uuid_bytes, 3)::BIGINT
            ) / 4;
            invite_code := '';
            FOR digit IN 1..6 LOOP
                invite_code := SUBSTRING(
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
                    (random_value % 32)::INTEGER + 1,
                    1
                ) || invite_code;
                random_value := random_value / 32;
            END LOOP;

            EXIT WHEN NOT EXISTS (
                SELECT 1 FROM groups WHERE groups.invite_url = invite_code
            );
        END LOOP;

        UPDATE groups
        SET invite_url = invite_code,
            update_date = NOW()
        WHERE id = target_group_id;
    END LOOP;
END
$$;
