CREATE OR REPLACE FUNCTION pg_schema()
RETURNS TABLE(table_name text)
LANGUAGE sql
AS $$
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';
$$;
