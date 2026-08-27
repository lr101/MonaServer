UPDATE pins
SET state_province_id = (
    SELECT a.id
    FROM admin2_boundaries a
    ORDER BY
        ST_Distance(
                a.geom,
                ST_SetSRID(ST_Point(pins.longitude, pins.latitude), 4326)
        )
    LIMIT 1
) where state_province_id IS NULL;