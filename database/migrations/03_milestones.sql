-- ============================================================================
-- 03_milestones.sql   |   Part 3: deliverables owned by a startup
-- ----------------------------------------------------------------------------
-- Requires: 02_startups_memberships.sql
-- Builds:   milestones
-- Apply in: Supabase Dashboard -> SQL Editor -> paste -> Run
-- ============================================================================


-- ----------------------------------------------------------------------------
-- milestones : one row per deliverable a startup commits to.
--   Rule 5 : every milestone belongs to exactly ONE startup (startup_id not null)
--   status              : Pending -> In_Progress -> Completed  (transitions: day 8)
--   verification_status : set by Mentor/Admin only             (rule 9: day 6)
--   completion_date     : allowed only when status = 'Completed'
-- ----------------------------------------------------------------------------
create table public.milestones (
    milestone_id         bigint generated always as identity primary key,
    startup_id           bigint      not null
                                     references public.startups (startup_id) on delete cascade,
    milestone_name       text        not null,
    description          text,
    due_date             date        not null,
    completion_date      date,
    status               text        not null default 'Pending',
    verification_status  text        not null default 'Unverified',
    mentor_remarks       text,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),

    constraint milestones_name_not_blank
        check (length(trim(milestone_name)) > 0),
    constraint milestones_status_check
        check (status in ('Pending', 'In_Progress', 'Completed')),
    constraint milestones_verification_status_check
        check (verification_status in ('Unverified', 'Verified', 'Rejected')),
    constraint milestones_completion_needs_completed_status
        check (completion_date is null or status = 'Completed'),
    constraint milestones_unique_name_per_startup
        unique (startup_id, milestone_name)
);

comment on table public.milestones is
    'Deliverables. Each belongs to exactly one startup (rule 5). Only Mentor/Admin verify (rule 9).';


-- ----------------------------------------------------------------------------
-- Indexes
-- ----------------------------------------------------------------------------
create index idx_milestones_startup_id on public.milestones (startup_id);
create index idx_milestones_status     on public.milestones (status);


-- ----------------------------------------------------------------------------
-- Row Level Security: lock the table (policies come in 06_policies.sql)
-- ----------------------------------------------------------------------------
alter table public.milestones enable row level security;


-- ----------------------------------------------------------------------------
-- check
-- ----------------------------------------------------------------------------
select 'milestones' as tbl, count(*) as rows from public.milestones;
