CREATE database ${POSTGRES_DB};

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE TABLE admin2_boundaries (
       id uuid DEFAULT gen_random_uuid() PRIMARY KEY,  -- A unique identifier for each feature
       gid_0 TEXT,                 -- Country GID
       name_0 TEXT,                -- Country name
       gid_1 TEXT,                 -- First-level administrative GID
       name_1 TEXT,                -- First-level administrative name
       nl_name_1 TEXT,             -- Native language name for level 1
       gid_2 TEXT,                 -- Second-level administrative GID
       name_2 TEXT,                -- Second-level administrative name
       varname_2 TEXT,             -- Alternate names
       nl_name_2 TEXT,             -- Native language name for level 2
       type_2 TEXT,                -- Type of administrative division
       engtype_2 TEXT,             -- English type
       cc_2 TEXT,                  -- Country code
       hasc_2 TEXT,                -- Hierarchical administrative subdivision code
       geom  GEOMETRY(MULTIPOLYGON, 4326)
);

CREATE INDEX IF NOT EXISTS idx_admin2_boundaries_geom ON admin2_boundaries USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_gid_0 ON admin2_boundaries(gid_0);
CREATE INDEX IF NOT EXISTS idx_gid_0 ON admin2_boundaries(gid_1);
CREATE INDEX IF NOT EXISTS idx_gid_0 ON admin2_boundaries(gid_2);
