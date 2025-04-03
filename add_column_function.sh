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
CREATE OR REPLACE FUNCTION public.add_column(
  table_name_in text,
  column_name_in text,
  schema_name_in text DEFAULT 'public',
  type_in text DEFAULT 'text',
  is_array boolean DEFAULT false
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS \$function\$
DECLARE
  _type_exists BOOLEAN;
BEGIN
  -- Check if the type exists among common PostgreSQL types
  SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = type_in)
  INTO _type_exists;

  IF NOT _type_exists THEN
    RETURN 'Invalid type: ' || type_in;
  END IF;

  -- Add the column to the specified schema and table
  IF is_array THEN
    EXECUTE format('ALTER TABLE %I.%I ADD COLUMN %I %I[];', schema_name_in, table_name_in, column_name_in, type_in);
  ELSE
    EXECUTE format('ALTER TABLE %I.%I ADD COLUMN %I %I;', schema_name_in, table_name_in, column_name_in, type_in);
  END IF;

  RETURN 'DONE';
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'Error: ' || SQLERRM;
END;
\$function\$;
EOF
)

# Drop any existing function called add_column before executing the SQL command
psql -U "$PG_USER" -h $PG_HOST -p $PG_PORT -d "$DB_NAME" -c "DROP FUNCTION IF EXISTS public.add_column(text, text, text, text, boolean);"
psql -U "$PG_USER" -h $PG_HOST -p $PG_PORT -d "$DB_NAME" -c "$SQL_COMMAND"
