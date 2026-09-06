-- ============================================================================
-- 00_reset.sql   |   ⚠️  DESTRUCTIVE. Wipes the ENTIRE public schema so the
--                     module (and the teammate modules) rebuild from clean.
-- ----------------------------------------------------------------------------
-- Does NOT delete login accounts. Clear those in
--   Dashboard -> Authentication -> Users
-- (deleting an auth user cascades its public.users profile row).
--
-- Run order for the whole backend:
--   00_reset -> 01 -> 02 -> 03 -> 04 -> (add 5 auth users) -> 05
--            -> 06 -> 07 -> 08 -> 20 -> 30 -> 40
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================

-- 1. the signup trigger (the only object this backend adds outside `public`)
drop trigger if exists on_auth_user_created on auth.users;

-- 2. every table in `public`  (cascade also drops its policies, triggers, FKs,
--    indexes and identity sequences)
do $$
declare r record;
begin
    for r in select tablename from pg_tables where schemaname = 'public'
    loop
        execute format('drop table if exists public.%I cascade', r.tablename);
    end loop;
end $$;

-- 3. every function in `public`  (helpers, guards, RPCs, and any old leftovers)
do $$
declare r record;
begin
    for r in
        select p.proname, pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
    loop
        execute format('drop function if exists public.%I(%s) cascade', r.proname, r.args);
    end loop;
end $$;

-- ----------------------------------------------------------------------------
-- proof: BOTH must return zero rows
-- ----------------------------------------------------------------------------
select tablename as leftover_table
from pg_tables where schemaname = 'public'
order by 1;

select p.proname as leftover_function
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 1;
