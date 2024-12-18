#!/bin/bash
set -e

echo "Waiting for PostgreSQL to start..."
until pg_isready -h localhost -p 5432 -U postgres; do
  sleep 1
done

echo "PostgreSQL is ready. Importing GeoJSON data..."

# Import GeoJSON file into the `countries` table
ogr2ogr -f "PostgreSQL" PG:"host=localhost dbname=${POSTGRES_DB} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}" \
    -nln admin2_boundaries \
    -append /docker-entrypoint-initdb.d/world_admin_2.geojson

echo "GeoJSON import complete."
