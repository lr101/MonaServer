CREATE INDEX IF NOT EXISTS idx_pins_active_location_geography
    ON pins USING GIST (
        (ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography)
    )
    WHERE is_deleted = FALSE;
