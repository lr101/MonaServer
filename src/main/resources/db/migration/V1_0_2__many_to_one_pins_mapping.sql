-- V1__migrate_groups_pins_to_group_id.sql

-- Step 1: Add the group_id column to the pins table
ALTER TABLE pins
    ADD COLUMN group_id uuid;

-- Step 2: Populate the group_id column using the existing groups_pins table
UPDATE pins p
SET group_id = gp.group_id
FROM groups_pins gp
WHERE p.id = gp.pin_id;

-- Step 3: Optionally, you might want to handle duplicate mappings if any pin is linked to multiple groups.
-- Here, we'll assume pins with multiple groups should be linked to the first group by id (or another rule).
-- If no special handling is required, this step can be skipped.

-- Optional Step: Handle duplicates
-- DELETE FROM groups_pins gp
-- USING groups_pins gp2
-- WHERE gp.pin_id = gp2.pin_id
-- AND gp.group_id > gp2.group_id;

-- Step 4: Drop the groups_pins table
DROP TABLE groups_pins;

-- Step 5: Add a foreign key constraint (optional)
ALTER TABLE pins
    ADD CONSTRAINT fk_group
        FOREIGN KEY (group_id) REFERENCES groups(id);
