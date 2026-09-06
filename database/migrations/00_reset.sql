-- ============================================================================
-- 00_reset.sql   |   ⚠️  ONE-TIME, DESTRUCTIVE. Run once on a shared project.
-- ----------------------------------------------------------------------------
-- Wipes every old/duplicate table so the module can be rebuilt from a clean
-- slate. Does NOT delete login accounts (auth.users is not touched here).
-- Login accounts are cleared separately from Dashboard -> Authentication -> Users
-- (or:  delete from auth.users;).
--
-- Run order for the whole module:  00_reset -> 01 -> 02 -> 03
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================

-- old signup automation + helper functions from earlier attempts
drop trigger  if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.is_admin() cascade;

-- old tables. "quoted" names were created with capital letters.
-- cascade also removes their foreign keys, policies and indexes.
drop table if exists public."Milestone"           cascade;
drop table if exists public."Startup_Membership"  cascade;
drop table if exists public."Startup"             cascade;
drop table if exists public."User"                cascade;
drop table if exists public."Role"                cascade;
drop table if exists public.milestone             cascade;
drop table if exists public.startup_membership    cascade;
drop table if exists public.startup               cascade;
drop table if exists public.users                 cascade;
drop table if exists public.role                  cascade;
drop table if exists public.task                  cascade;

-- proof: should return ZERO rows
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
