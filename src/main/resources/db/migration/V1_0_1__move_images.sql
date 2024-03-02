
-- 1. Alter the 'pins' table to add the 'image' column
ALTER TABLE pins ADD COLUMN IF NOT EXISTS image OID;

-- 2. Migrate data from 'monas' to 'pins' if needed
-- This step is necessary if there is existing data in 'monas' that needs to be preserved
-- It assumes a relationship between 'monas' and 'pins', which needs to be established based on your application logic
-- Example:
DO $$
    BEGIN
        -- Check if the "monas" table exists
        IF EXISTS (SELECT FROM pg_catalog.pg_tables
                   WHERE schemaname = 'public' AND tablename = 'monas') THEN
            -- Perform the update if the table exists
            UPDATE pins SET image = monas.image FROM monas WHERE pins.id = monas.pin;
        END IF;
    END $$;



-- 3. Remove the 'monas' table
DROP TABLE IF EXISTS monas;