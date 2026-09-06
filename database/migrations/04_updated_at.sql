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

-- Attach it to all five tables.
create trigger trg_roles_updated_at
    before update on public.roles
    for each row execute function public.set_updated_at();

create trigger trg_users_updated_at
    before update on public.users
    for each row execute function public.set_updated_at();

create trigger trg_startups_updated_at
    before update on public.startups
    for each row execute function public.set_updated_at();

create trigger trg_memberships_updated_at
    before update on public.startup_memberships
    for each row execute function public.set_updated_at();

create trigger trg_milestones_updated_at
    before update on public.milestones
    for each row execute function public.set_updated_at();

-- check: expect 5 rows
select tgname as trigger_name, tgrelid::regclass as on_table
from pg_trigger
where tgname like 'trg_%_updated_at'
order by on_table;
