
-- 1. Alter the 'pins' table to add the 'image' column
ALTER TABLE groups ADD COLUMN IF NOT EXISTS group_profile BYTEA NULL;


-- Function to import large objects into the new table
CREATE OR REPLACE FUNCTION import_large_objects()
    RETURNS VOID AS
$$
DECLARE
    loid OID;
    lob BYTEA;
BEGIN
    -- Loop through the large objects and import them into the new table
    FOR loid IN (SELECT DISTINCT profile_image FROM groups) LOOP
            -- Get the large object data
            SELECT lo_get(loid) INTO lob;

            -- Insert the large object data into the new table
            UPDATE groups SET group_profile = lob WHERE profile_image = loid;
        END LOOP;
END;
$$
    LANGUAGE plpgsql;


DO $$
    BEGIN
        -- Check if the "monas" table exists
        IF EXISTS (
            SELECT FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'groups' AND column_name = 'profile_image'
        ) THEN
            -- Execute the function to import large objects
            PERFORM import_large_objects();
        END IF;
    END $$;

ALTER TABLE groups
    DROP COLUMN IF EXISTS profile_image;
ALTER TABLE groups
    ALTER COLUMN group_profile TYPE BYTEA;