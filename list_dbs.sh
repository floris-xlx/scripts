#!/bin/bash

# Set PostgreSQL username and password
PG_USER="postgres"
PG_PASSWORD="new_secure_password"
export PGPASSWORD=$PG_PASSWORD

# Function to get tables for a given database
get_tables() {
    local db_name=$1
    psql -U "$PG_USER" -h db.xylex.cloud -p 5432 -d "$db_name" -t -A -F "," -c "SELECT json_agg(table_name) FROM information_schema.tables WHERE table_schema = 'public';"
}
 
# Query PostgreSQL to list databases and format output as JSON
databases=$(psql -U "$PG_USER" -d postgres -h db.xylex.cloud -p 5432 -t -A -F "," -c "SELECT json_agg(json_build_object(
    'name', datname,
    'owner', pg_catalog.pg_get_userbyid(datdba),
    'encoding', pg_catalog.pg_encoding_to_char(encoding),
    'collate', datcollate,
    'ctype', datctype
)) FROM pg_database WHERE datistemplate = false;")

# Parse the JSON and add tables for each database
echo "$databases" | jq -c '.[]' | while read db; do
    db_name=$(echo "$db" | jq -r '.name')
    tables=$(get_tables "$db_name")
    echo "$db" | jq --argjson tables "$tables" '. + {tables: $tables}'
done | jq -s '.'
