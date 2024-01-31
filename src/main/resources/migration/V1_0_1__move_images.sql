
-- 1. Alter the 'pins' table to add the 'image' column
ALTER TABLE pins ADD COLUMN image OID;

-- 2. Migrate data from 'monas' to 'pins' if needed
-- This step is necessary if there is existing data in 'monas' that needs to be preserved
-- It assumes a relationship between 'monas' and 'pins', which needs to be established based on your application logic
-- Example:
UPDATE pins SET image = monas.image FROM monas WHERE pins.id = monas.pin;

-- 3. Remove the 'monas' table
DROP TABLE monas;