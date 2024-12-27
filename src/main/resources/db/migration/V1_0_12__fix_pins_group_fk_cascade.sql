ALTER TABLE pins DROP CONSTRAINT fk_group;
ALTER TABLE pins ADD CONSTRAINT fk_group FOREIGN KEY (group_id) REFERENCES groups(id) on delete cascade;