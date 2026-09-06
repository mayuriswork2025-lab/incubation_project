-- ============================================================================
-- 08_functions.sql   |   Phase D: business operations (RPC)
-- ----------------------------------------------------------------------------
-- Requires: 01-03, 06, 07.
-- Multi-step / permission-checked actions. Call from the app with
--   supabase.rpc('function_name', { p_arg: ... })
-- All are SECURITY DEFINER: they run with full rights but check the caller's
-- permission (auth.uid() / role) before doing anything.
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- create_startup_with_founder   — Rule 2: startup + first founder, atomically.
-- Caller must have system role Founder or Admin.
-- ----------------------------------------------------------------------------
create or replace function public.create_startup_with_founder(
    p_startup_name text,
    p_domain       text default null,
    p_description  text default null
)
returns public.startups
language plpgsql security definer set search_path = ''
as $$
declare
    v_uid     uuid := (select auth.uid());
    v_role    text := public.current_user_role();
    v_startup public.startups;
begin
    if v_uid is null then
        raise exception 'You must be signed in.' using errcode = '28000';
    end if;
    if v_role is null or v_role not in ('Founder', 'Admin') then
        raise exception 'Only a Founder or Admin can register a startup.' using errcode = '42501';
    end if;
    if length(trim(coalesce(p_startup_name, ''))) = 0 then
        raise exception 'Startup name is required.' using errcode = '23514';
    end if;

    insert into public.startups (startup_name, domain, description, registered_by)
    values (trim(p_startup_name),
            nullif(trim(coalesce(p_domain, '')), ''),
            nullif(trim(coalesce(p_description, '')), ''),
            v_uid)
    returning * into v_startup;

    insert into public.startup_memberships (startup_id, user_id, project_role)
    values (v_startup.startup_id, v_uid, 'Founder');

    return v_startup;
end;
$$;
revoke all on function public.create_startup_with_founder(text, text, text) from public;
grant execute on function public.create_startup_with_founder(text, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- add_startup_member / remove_startup_member / promote_to_founder
-- Only a founder of that startup (or an Admin) may manage its roster.
-- ----------------------------------------------------------------------------
create or replace function public.add_startup_member(
    p_startup_id   bigint,
    p_user_id      uuid,
    p_project_role text default 'Member'
)
returns public.startup_memberships
language plpgsql security definer set search_path = ''
as $$
declare v_row public.startup_memberships;
begin
    if not (public.is_admin() or public.is_startup_founder(p_startup_id)) then
        raise exception 'Only a founder of this startup (or an Admin) can add members.' using errcode = '42501';
    end if;
    if p_project_role not in ('Founder', 'Member') then
        raise exception 'project_role must be Founder or Member.' using errcode = '23514';
    end if;

    insert into public.startup_memberships (startup_id, user_id, project_role)
    values (p_startup_id, p_user_id, p_project_role)
    returning * into v_row;
    return v_row;
end;
$$;
revoke all on function public.add_startup_member(bigint, uuid, text) from public;
grant execute on function public.add_startup_member(bigint, uuid, text) to authenticated;


create or replace function public.remove_startup_member(p_startup_id bigint, p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
    if not (public.is_admin() or public.is_startup_founder(p_startup_id)) then
        raise exception 'Only a founder of this startup (or an Admin) can remove members.' using errcode = '42501';
    end if;
    delete from public.startup_memberships
    where startup_id = p_startup_id and user_id = p_user_id;
    -- removing the last founder is blocked by trg_memberships_guard_last_founder
end;
$$;
revoke all on function public.remove_startup_member(bigint, uuid) from public;
grant execute on function public.remove_startup_member(bigint, uuid) to authenticated;


create or replace function public.promote_to_founder(p_startup_id bigint, p_user_id uuid)
returns public.startup_memberships
language plpgsql security definer set search_path = ''
as $$
declare v_row public.startup_memberships;
begin
    if not (public.is_admin() or public.is_startup_founder(p_startup_id)) then
        raise exception 'Only a founder of this startup (or an Admin) can promote members.' using errcode = '42501';
    end if;
    update public.startup_memberships
    set project_role = 'Founder'
    where startup_id = p_startup_id and user_id = p_user_id
    returning * into v_row;
    if v_row is null then
        raise exception 'That user is not a member of this startup.' using errcode = 'P0002';
    end if;
    return v_row;
end;
$$;
revoke all on function public.promote_to_founder(bigint, uuid) from public;
grant execute on function public.promote_to_founder(bigint, uuid) to authenticated;


-- ----------------------------------------------------------------------------
-- set_milestone_status  — founder of the owning startup (or Admin).
-- The transition itself is validated by trg_milestone_guard_status_flow.
-- ----------------------------------------------------------------------------
create or replace function public.set_milestone_status(p_milestone_id bigint, p_new_status text)
returns public.milestones
language plpgsql security definer set search_path = ''
as $$
declare
    v_startup_id bigint;
    v_row public.milestones;
begin
    select startup_id into v_startup_id from public.milestones where milestone_id = p_milestone_id;
    if v_startup_id is null then
        raise exception 'Milestone % not found.', p_milestone_id using errcode = 'P0002';
    end if;
    if not (public.is_admin() or public.is_startup_founder(v_startup_id)) then
        raise exception 'Only a founder of this startup (or an Admin) can change milestone status.' using errcode = '42501';
    end if;

    update public.milestones set status = p_new_status
    where milestone_id = p_milestone_id
    returning * into v_row;
    return v_row;
end;
$$;
revoke all on function public.set_milestone_status(bigint, text) from public;
grant execute on function public.set_milestone_status(bigint, text) to authenticated;


-- ----------------------------------------------------------------------------
-- verify_milestone   — Mentor or Admin only (Rule 9).
-- ----------------------------------------------------------------------------
create or replace function public.verify_milestone(
    p_milestone_id bigint,
    p_verification text,
    p_remarks      text default null
)
returns public.milestones
language plpgsql security definer set search_path = ''
as $$
declare
    v_role text := public.current_user_role();
    v_row public.milestones;
begin
    if v_role is null or v_role not in ('Mentor', 'Admin') then
        raise exception 'Only a Mentor or Admin can verify a milestone.' using errcode = '42501';
    end if;
    if p_verification not in ('Unverified', 'Verified', 'Rejected') then
        raise exception 'verification must be Unverified, Verified or Rejected.' using errcode = '23514';
    end if;

    update public.milestones
    set verification_status = p_verification,
        mentor_remarks      = coalesce(p_remarks, mentor_remarks)
    where milestone_id = p_milestone_id
    returning * into v_row;
    if v_row is null then
        raise exception 'Milestone % not found.', p_milestone_id using errcode = 'P0002';
    end if;
    return v_row;
end;
$$;
revoke all on function public.verify_milestone(bigint, text, text) from public;
grant execute on function public.verify_milestone(bigint, text, text) to authenticated;


-- ----------------------------------------------------------------------------
-- set_startup_status   — Admin only. The approve / reject action.
-- ----------------------------------------------------------------------------
create or replace function public.set_startup_status(p_startup_id bigint, p_status text)
returns public.startups
language plpgsql security definer set search_path = ''
as $$
declare v_row public.startups;
begin
    if not public.is_admin() then
        raise exception 'Only an Admin can approve or reject a startup.' using errcode = '42501';
    end if;
    if p_status not in ('Pending', 'Approved', 'Rejected') then
        raise exception 'status must be Pending, Approved or Rejected.' using errcode = '23514';
    end if;
    update public.startups set registration_status = p_status
    where startup_id = p_startup_id
    returning * into v_row;
    if v_row is null then
        raise exception 'Startup % not found.', p_startup_id using errcode = 'P0002';
    end if;
    return v_row;
end;
$$;
revoke all on function public.set_startup_status(bigint, text) from public;
grant execute on function public.set_startup_status(bigint, text) to authenticated;


-- ----------------------------------------------------------------------------
-- assign_user_role   — Admin only. The ONLY sanctioned way a role changes (Rule 8).
-- ----------------------------------------------------------------------------
create or replace function public.assign_user_role(p_user_id uuid, p_role_name text)
returns public.users
language plpgsql security definer set search_path = ''
as $$
declare
    v_role_id bigint;
    v_row public.users;
begin
    if not public.is_admin() then
        raise exception 'Only an Admin can assign roles.' using errcode = '42501';
    end if;
    select role_id into v_role_id from public.roles where role_name = p_role_name;
    if v_role_id is null then
        raise exception 'Role "%" does not exist.', p_role_name using errcode = '23503';
    end if;
    update public.users set role_id = v_role_id
    where user_id = p_user_id
    returning * into v_row;
    if v_row is null then
        raise exception 'User not found.' using errcode = 'P0002';
    end if;
    return v_row;
end;
$$;
revoke all on function public.assign_user_role(uuid, text) from public;
grant execute on function public.assign_user_role(uuid, text) to authenticated;


-- ----------------------------------------------------------------------------
-- check: expect 8 function rows
-- ----------------------------------------------------------------------------
select routine_name
from information_schema.routines
where routine_schema = 'public' and routine_type = 'FUNCTION'
  and routine_name in (
    'create_startup_with_founder','add_startup_member','remove_startup_member',
    'promote_to_founder','set_milestone_status','verify_milestone',
    'set_startup_status','assign_user_role')
order by routine_name;
