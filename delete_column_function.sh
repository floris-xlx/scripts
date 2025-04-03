#!/bin/bash

# Set PostgreSQL username and password
PG_USER="postgres"
PG_PASSWORD="new_secure_password"
PG_PORT=5432
PG_HOST=db.xylex.cloud
export PGPASSWORD=$PG_PASSWORD

# Function to display usage message and exit
usage() {
  echo "Usage: $0 --db_name=<DB_NAME>"
  exit 1
}

# Initialize database name variable
DB_NAME=""

# Function to parse command-line arguments
parse_arguments() {
  for arg in "$@"; do
    case $arg in
    --db_name=*)
      DB_NAME="${arg#*=}"
      shift
      ;;
    *)
      echo "Error: Invalid argument: $arg"
      usage
      ;;
    esac
  done
}

# Function to validate required arguments
validate_arguments() {
  if [ -z "$DB_NAME" ]; then
    echo "Error: --db_name is required"
    usage
  fi
}

# Parse and validate arguments
parse_arguments "$@"
validate_arguments

SQL_COMMAND=$(
  cat <<EOF
CREATE OR REPLACE FUNCTION public.delete_column(
  table_name_in text,
  column_name_in text,
  schema_name_in text DEFAULT 'public'
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS \$function\$
BEGIN
  -- Delete the column from the specified schema and table
  EXECUTE format('ALTER TABLE %I.%I DROP COLUMN IF EXISTS %I;', schema_name_in, table_name_in, column_name_in);

  RETURN 'DONE';
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'Error: ' || SQLERRM;
END;
\$function\$;
EOF
)

# Drop any existing function called delete_column before executing the SQL command
psql -U "$PG_USER" -h $PG_HOST -p $PG_PORT -d "$DB_NAME" -c "DROP FUNCTION IF EXISTS public.delete_column(text, text, text);"
psql -U "$PG_USER" -h $PG_HOST -p $PG_PORT -d "$DB_NAME" -c "$SQL_COMMAND"
