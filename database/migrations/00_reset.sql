drop trigger  if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.is_admin() cascade;

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

select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
