#!/bin/bash

# Set PostgreSQL username and password
PG_USER="postgres"
PG_PASSWORD="new_secure_password"
export PGPASSWORD=$PG_PASSWORD


# Usage message
usage() {
    echo "Usage: $0 --DB_NAME <DB_NAME>"
    exit 1
}

DB_NAME=""

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
    --db_name)
        DB_NAME="$2"
        shift 2
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z "$DB_NAME" ]; then
    usage
fi

# Function to get columns for a given table
get_columns() {
    local db_name=$1
    local table_name=$2
    psql -U "$PG_USER" -h db.xylex.cloud -p 5432 -d "$db_name" -t -A -F "," -c "SELECT json_agg(json_build_object('column_name', column_name, 'data_type', data_type)) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '$table_name';"
}

# Function to get tables and their columns for a given database
get_tables_and_columns() {
    local db_name=$1
    tables=$(psql -U "$PG_USER" -h db.xylex.cloud -p 5432 -d "$db_name" -t -A -F "," -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';")
    echo "$tables" | while IFS= read -r table_name; do
        columns=$(get_columns "$db_name" "$table_name")
        echo "{\"table_name\": \"$table_name\", \"columns\": $columns}"
    done | jq -s '.'
}

# Get tables and columns for the specified database
get_tables_and_columns "$DB_NAME"

