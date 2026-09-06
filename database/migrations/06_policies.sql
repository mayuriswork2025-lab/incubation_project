-- ============================================================================
-- 06_policies.sql   |   Phase B: Row Level Security — who can do what
-- ----------------------------------------------------------------------------
-- Requires: 01, 02, 03
-- RLS is already ENABLED on all 5 tables (from 01-03). This file adds the
-- policies + the helper functions they rely on.
--
-- Enforces business rules 6 (founders manage their startup), 7 (members
-- read-only), 10 (DB-level authorization).
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Make sure the app roles can reach the tables at all.
--    (Supabase usually grants this automatically; harmless to repeat.)
-- ----------------------------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;


-- ----------------------------------------------------------------------------
-- 1. Helper functions.
--    SECURITY DEFINER  -> they run as the owner, so they BYPASS RLS on the
--                         tables they read. This is what stops a policy on
--                         startup_memberships that reads startup_memberships
--                         from looping forever.
--    set search_path = '' -> hardening (must schema-qualify everything inside).
-- ----------------------------------------------------------------------------
create or replace function public.current_user_role()
returns text
language sql stable security definer set search_path = ''
as $$
    select r.role_name
    from public.users u
    join public.roles r on r.role_id = u.role_id
    where u.user_id = (select auth.uid());
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
    select public.current_user_role() = 'Admin';
$$;

create or replace function public.is_startup_member(p_startup_id bigint)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.startup_memberships sm
        where sm.startup_id = p_startup_id
          and sm.user_id = (select auth.uid())
    );
$$;

create or replace function public.is_startup_founder(p_startup_id bigint)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.startup_memberships sm
        where sm.startup_id = p_startup_id
          and sm.user_id = (select auth.uid())
          and sm.project_role = 'Founder'
    );
$$;


-- ----------------------------------------------------------------------------
-- 2. roles  — everyone signed in can read; only Admin writes
-- ----------------------------------------------------------------------------
create policy roles_select on public.roles
    for select to authenticated using (true);

create policy roles_insert on public.roles
    for insert to authenticated with check (public.is_admin());

create policy roles_update on public.roles
    for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy roles_delete on public.roles
    for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 3. users  — everyone reads profiles; you edit only your own row (or Admin).
--    (Blocking a change to your OWN role/status is done by a trigger in 07.)
-- ----------------------------------------------------------------------------
create policy users_select on public.users
    for select to authenticated using (true);

create policy users_update on public.users
    for update to authenticated
    using  (user_id = (select auth.uid()) or public.is_admin())
    with check (user_id = (select auth.uid()) or public.is_admin());

create policy users_insert on public.users
    for insert to authenticated with check (public.is_admin());

create policy users_delete on public.users
    for delete to authenticated using (public.is_admin());


-- ----------------------------------------------------------------------------
-- 4. startups
--    read   : members of the startup, any Mentor, Admin
--    create : a user whose system role is Founder or Admin, setting themselves
--             as registered_by  (the atomic path is create_startup_with_founder)
--    edit   : that startup's founders, or Admin
--    delete : that startup's founders, or Admin
-- ----------------------------------------------------------------------------
create policy startups_select on public.startups
    for select to authenticated
    using (
        public.is_admin()
        or public.is_startup_member(startup_id)
        or public.current_user_role() = 'Mentor'
    );

create policy startups_insert on public.startups
    for insert to authenticated
    with check (
        registered_by = (select auth.uid())
        and public.current_user_role() in ('Founder', 'Admin')
    );

create policy startups_update on public.startups
    for update to authenticated
    using  (public.is_admin() or public.is_startup_founder(startup_id))
    with check (public.is_admin() or public.is_startup_founder(startup_id));

create policy startups_delete on public.startups
    for delete to authenticated
    using (public.is_admin() or public.is_startup_founder(startup_id));


-- ----------------------------------------------------------------------------
-- 5. startup_memberships
--    read   : your own rows, co-members of the startup, Admin
--    write  : that startup's founders, or Admin
-- ----------------------------------------------------------------------------
create policy memberships_select on public.startup_memberships
    for select to authenticated
    using (
        public.is_admin()
        or user_id = (select auth.uid())
        or public.is_startup_member(startup_id)
    );

create policy memberships_insert on public.startup_memberships
    for insert to authenticated
    with check (public.is_admin() or public.is_startup_founder(startup_id));

create policy memberships_update on public.startup_memberships
    for update to authenticated
    using  (public.is_admin() or public.is_startup_founder(startup_id))
    with check (public.is_admin() or public.is_startup_founder(startup_id));

create policy memberships_delete on public.startup_memberships
    for delete to authenticated
    using (public.is_admin() or public.is_startup_founder(startup_id));


-- ----------------------------------------------------------------------------
-- 6. milestones
--    read   : members of the owning startup, any Mentor, Admin
--    create : that startup's founders, or Admin
--    edit   : that startup's founders, any Mentor, Admin
--             (a trigger in 07 restricts verification_status to Mentor/Admin)
--    delete : that startup's founders, or Admin
-- ----------------------------------------------------------------------------
create policy milestones_select on public.milestones
    for select to authenticated
    using (
        public.is_admin()
        or public.is_startup_member(startup_id)
        or public.current_user_role() = 'Mentor'
    );

create policy milestones_insert on public.milestones
    for insert to authenticated
    with check (public.is_admin() or public.is_startup_founder(startup_id));

create policy milestones_update on public.milestones
    for update to authenticated
    using (
        public.is_admin()
        or public.is_startup_founder(startup_id)
        or public.current_user_role() = 'Mentor'
    )
    with check (
        public.is_admin()
        or public.is_startup_founder(startup_id)
        or public.current_user_role() = 'Mentor'
    );

create policy milestones_delete on public.milestones
    for delete to authenticated
    using (public.is_admin() or public.is_startup_founder(startup_id));


-- ----------------------------------------------------------------------------
-- check: expect ~20 rows (4 per table)
-- ----------------------------------------------------------------------------
select tablename, cmd, policyname
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;
