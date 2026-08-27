CREATE TABLE IF NOT EXISTS admin2_boundaries
(
    id     UUID NOT NULL,
    gid_0  VARCHAR(255),
    name_0 VARCHAR(255),
    gid_1  VARCHAR(255),
    name_1 VARCHAR(255),
    gid_2  VARCHAR(255),
    name_2 VARCHAR(255),
    CONSTRAINT pk_admin2_boundaries PRIMARY KEY (id)
);