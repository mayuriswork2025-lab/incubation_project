-- ============================================================================
-- 01_roles_users.sql   |   Part 1 of the module: identity (who a person is)
-- ----------------------------------------------------------------------------
-- Requires: 00_reset.sql (clean slate)
-- Builds:   roles, users, the signup trigger
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- roles : the fixed set of SYSTEM roles. Every user has exactly one.
--         (This is different from a person's per-startup "project role",
--          which is Founder/Member and lives in startup_memberships.)
-- ----------------------------------------------------------------------------
create table public.roles (
    role_id      bigint generated always as identity primary key,
    role_name    text        not null,
    description  text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),

    constraint roles_role_name_unique     unique (role_name),
    constraint roles_role_name_not_blank  check  (length(trim(role_name)) > 0)
);

comment on table public.roles is
    'System roles. One per user (users.role_id). Managed by Admins only.';

insert into public.roles (role_name, description) values
    ('Admin',   'Full platform access; manages users and roles'),
    ('Mentor',  'Advises startups and verifies milestones'),
    ('Founder', 'Startup-track user; founds or joins startup teams'),
    ('Judge',   'Scores startups at demo days');


-- ----------------------------------------------------------------------------
-- users : the application PROFILE. One row per person.
--         Primary key = the Supabase Auth account id.
--         Supabase Auth owns email + password in auth.users; we never
--         store credentials here.
-- ----------------------------------------------------------------------------
create table public.users (
    user_id     uuid   primary key
                       references auth.users (id) on delete cascade,
    role_id     bigint not null
                       references public.roles (role_id) on delete restrict,
    first_name  text        not null,
    last_name   text        not null,
    email       text        not null,
    phone       text,
    department  text,
    status      text        not null default 'Active',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),

    constraint users_email_unique          unique (email),
    constraint users_phone_unique          unique (phone),
    constraint users_first_name_not_blank  check  (length(trim(first_name)) > 0),
    constraint users_last_name_not_blank   check  (length(trim(last_name))  > 0),
    constraint users_status_check
        check (status in ('Active', 'Inactive', 'Suspended'))
);

comment on table public.users is
    'User profile, 1:1 with auth.users. No credentials here - Supabase Auth owns them.';


-- ----------------------------------------------------------------------------
-- Row Level Security: lock both tables now. Access policies are added later
-- in 06_policies.sql. The SQL Editor and the trigger below still work because
-- they run with elevated rights.
-- ----------------------------------------------------------------------------
alter table public.roles enable row level security;
alter table public.users enable row level security;


-- ----------------------------------------------------------------------------
-- handle_new_user : when a row is added to auth.users (someone signs up),
-- automatically create their matching profile row.
--   - role is ALWAYS 'Founder'; the client cannot pick its own role (rule 8)
--   - first/last name come from signup metadata when provided
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    founder_role_id bigint;
begin
    select role_id into founder_role_id
    from public.roles
    where role_name = 'Founder';

    insert into public.users (user_id, role_id, first_name, last_name, email)
    values (
        new.id,
        founder_role_id,
        coalesce(nullif(trim(new.raw_user_meta_data ->> 'first_name'), ''), 'New'),
        coalesce(nullif(trim(new.raw_user_meta_data ->> 'last_name'),  ''), 'User'),
        new.email
    );

    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();


-- ----------------------------------------------------------------------------
-- check
-- ----------------------------------------------------------------------------
select role_id, role_name, description from public.roles order by role_id;
