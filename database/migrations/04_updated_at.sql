-- ============================================================================
-- 04_updated_at.sql   |   Keep updated_at accurate on every row change
-- ----------------------------------------------------------------------------
-- Requires: 01, 02, 03
-- Without this, updated_at just keeps its creation value forever.
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================

-- One shared function: set updated_at to "now" just before any UPDATE.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

-- Attach it to all five tables. (drop-first so the script is safe to re-run.)
drop trigger if exists trg_roles_updated_at on public.roles;
create trigger trg_roles_updated_at
    before update on public.roles
    for each row execute function public.set_updated_at();

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at
    before update on public.users
    for each row execute function public.set_updated_at();

drop trigger if exists trg_startups_updated_at on public.startups;
create trigger trg_startups_updated_at
    before update on public.startups
    for each row execute function public.set_updated_at();

drop trigger if exists trg_memberships_updated_at on public.startup_memberships;
create trigger trg_memberships_updated_at
    before update on public.startup_memberships
    for each row execute function public.set_updated_at();

drop trigger if exists trg_milestones_updated_at on public.milestones;
create trigger trg_milestones_updated_at
    before update on public.milestones
    for each row execute function public.set_updated_at();

-- check: expect 5 rows
select tgname as trigger_name, tgrelid::regclass as on_table
from pg_trigger
where tgname like 'trg_%_updated_at'
order by on_table;
