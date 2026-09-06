-- ============================================================================
-- 07_guards.sql   |   Phase C: column-level guards (triggers)
-- ----------------------------------------------------------------------------
-- Requires: 01-03, 06 (uses is_admin() / current_user_role()).
-- RLS (06) decides WHICH ROWS a user can touch. These triggers decide WHICH
-- COLUMNS / value changes are allowed. Enforces business rules 2, 8, 9.
--
-- Every guard skips when there is no logged-in user (auth.uid() is null) so
-- the SQL Editor, the seed script, and the service role stay unblocked.
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Rule 8 — you cannot change your OWN role or account status.
-- ----------------------------------------------------------------------------
create or replace function public.guard_users_self_privilege()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if (select auth.uid()) is null then return new; end if;   -- trusted context
    if public.is_admin() then return new; end if;             -- Admins may

    if new.role_id is distinct from old.role_id then
        raise exception 'You cannot change your own role (business rule 8). Ask an Admin.'
            using errcode = 'check_violation';
    end if;
    if new.status is distinct from old.status then
        raise exception 'You cannot change your own account status.'
            using errcode = 'check_violation';
    end if;
    return new;
end;
$$;

drop trigger if exists trg_users_guard_self_privilege on public.users;
create trigger trg_users_guard_self_privilege
    before update on public.users
    for each row execute function public.guard_users_self_privilege();


-- ----------------------------------------------------------------------------
-- Rule 9a — only a Mentor or Admin may set verification_status / mentor_remarks.
-- ----------------------------------------------------------------------------
create or replace function public.guard_milestone_verification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_role text;
begin
    if (select auth.uid()) is null then return new; end if;
    v_role := public.current_user_role();
    if v_role in ('Mentor', 'Admin') then return new; end if;

    if new.verification_status is distinct from old.verification_status
       or new.mentor_remarks is distinct from old.mentor_remarks then
        raise exception 'Only a Mentor or Admin can verify a milestone (business rule 9).'
            using errcode = 'check_violation';
    end if;
    return new;
end;
$$;

drop trigger if exists trg_milestone_guard_verification on public.milestones;
create trigger trg_milestone_guard_verification
    before update on public.milestones
    for each row execute function public.guard_milestone_verification();


-- ----------------------------------------------------------------------------
-- Rule 9b — milestone status only moves forward.
--   Pending -> In_Progress -> Completed   (and Pending -> Completed).
--   Never backwards. Completing auto-fills completion_date.
-- ----------------------------------------------------------------------------
create or replace function public.guard_milestone_status_flow()
returns trigger
language plpgsql set search_path = ''
as $$
begin
    if new.status = old.status then
        return new;
    end if;

    if (old.status = 'Pending'     and new.status in ('In_Progress', 'Completed'))
    or (old.status = 'In_Progress' and new.status = 'Completed') then
        if new.status = 'Completed' and new.completion_date is null then
            new.completion_date := current_date;
        end if;
        return new;
    end if;

    raise exception 'Milestone status cannot go from % to %. It only moves forward.',
        old.status, new.status
        using errcode = 'check_violation';
end;
$$;

drop trigger if exists trg_milestone_guard_status_flow on public.milestones;
create trigger trg_milestone_guard_status_flow
    before update on public.milestones
    for each row execute function public.guard_milestone_status_flow();


-- ----------------------------------------------------------------------------
-- Rule 2 — a startup must always keep at least one founder.
--   Blocks deleting or demoting the last remaining 'Founder' row.
-- ----------------------------------------------------------------------------
create or replace function public.guard_last_founder()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_founder_count int;
begin
    if (select auth.uid()) is null then
        return coalesce(new, old);   -- trusted context (seed, admin maintenance)
    end if;

    if tg_op = 'DELETE' then
        if old.project_role <> 'Founder' then return old; end if;
    else  -- UPDATE
        if old.project_role <> 'Founder' or new.project_role = 'Founder' then
            return new;
        end if;
    end if;

    select count(*) into v_founder_count
    from public.startup_memberships
    where startup_id = old.startup_id and project_role = 'Founder';

    if v_founder_count <= 1 then
        raise exception 'A startup must keep at least one founder (business rule 2). Promote another member first.'
            using errcode = 'check_violation';
    end if;

    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_memberships_guard_last_founder on public.startup_memberships;
create trigger trg_memberships_guard_last_founder
    before update or delete on public.startup_memberships
    for each row execute function public.guard_last_founder();


-- ----------------------------------------------------------------------------
-- check: expect 4 trigger rows
-- ----------------------------------------------------------------------------
select tgname as trigger_name, tgrelid::regclass as on_table
from pg_trigger
where tgname in (
    'trg_users_guard_self_privilege',
    'trg_milestone_guard_verification',
    'trg_milestone_guard_status_flow',
    'trg_memberships_guard_last_founder')
order by on_table, trigger_name;
