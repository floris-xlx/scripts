create or replace function public.execute_sql(sql text)
returns void as $$
begin
  execute sql;
end;
$$ language plpgsql security definer;
