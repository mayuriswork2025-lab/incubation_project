-- ============================================================================
-- 02_startups_memberships.sql   |   Part 2: startups and the people in them
-- ----------------------------------------------------------------------------
-- Requires: 01_roles_users.sql
-- Builds:   startups, startup_memberships (the junction table where
--           Founders and Members are defined)
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- startups : one row per startup.
--   registration_status lifecycle:  Pending -> Approved | Rejected
--   registered_by = who clicked "create" (AUDIT ONLY). The real founder(s)
--   are the rows in startup_memberships with project_role = 'Founder'.
-- ----------------------------------------------------------------------------
create table public.startups (
    startup_id           bigint generated always as identity primary key,
    startup_name         text        not null,
    domain               text,
    description          text,
    current_stage        text,
    registration_status  text        not null default 'Pending',
    registered_by        uuid        references public.users (user_id) on delete set null,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),

    constraint startups_name_not_blank
        check (length(trim(startup_name)) > 0),
    constraint startups_registration_status_check
        check (registration_status in ('Pending', 'Approved', 'Rejected'))
);

comment on table public.startups is
    'One row per startup. registered_by is audit only; founders live in startup_memberships.';


-- ----------------------------------------------------------------------------
-- startup_memberships : junction table (people <-> startups).
--   project_role : 'Founder' or 'Member'
--   Rule 2 : a startup has AT LEAST ONE founder  (kept by functions, day 8)
--   Rule 3 : a user cannot be in the same startup twice  (unique below)
-- ----------------------------------------------------------------------------
create table public.startup_memberships (
    membership_id  bigint generated always as identity primary key,
    startup_id     bigint      not null
                               references public.startups (startup_id) on delete cascade,
    user_id        uuid        not null
                               references public.users (user_id) on delete cascade,
    project_role   text        not null default 'Member',
    joined_at      timestamptz not null default now(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),

    constraint memberships_project_role_check
        check (project_role in ('Founder', 'Member')),
    constraint memberships_unique_user_per_startup
        unique (user_id, startup_id)
);

comment on table public.startup_memberships is
    'Who belongs to which startup, and as what (Founder/Member). Members exist here, not in roles.';


-- ----------------------------------------------------------------------------
-- Foreign-key indexes. Postgres does NOT create these automatically, and the
-- security checks in day 6 will query these columns constantly.
-- ----------------------------------------------------------------------------
create index idx_startups_registered_by  on public.startups            (registered_by);
create index idx_memberships_startup_id  on public.startup_memberships (startup_id);
create index idx_memberships_user_id     on public.startup_memberships (user_id);


-- ----------------------------------------------------------------------------
-- Row Level Security: lock both tables (policies come in 06_policies.sql)
-- ----------------------------------------------------------------------------
alter table public.startups            enable row level security;
alter table public.startup_memberships enable row level security;


-- ----------------------------------------------------------------------------
-- check
-- ----------------------------------------------------------------------------
select 'startups'            as tbl, count(*) as rows from public.startups
union all
select 'startup_memberships' as tbl, count(*) as rows from public.startup_memberships;
