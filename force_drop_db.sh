#!/bin/bash

# Check if a database name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <database_name>"
  exit 1
fi

DB_NAME=$1
PG_USER="postgres"
PG_PASSWORD="new_secure_password"

# Drop the database with FORCE (PostgreSQL 15+)
PGPASSWORD="$PG_PASSWORD" psql -U "$PG_USER" -d postgres -h db.xylex.cloud -p 5432 -c "DROP DATABASE \"$DB_NAME\" WITH (FORCE);"

# Check exit status
if [ $? -eq 0 ]; then
  echo "Database '$DB_NAME' dropped successfully."
else
  echo "Failed to drop database '$DB_NAME'."
  exit 1
fi
