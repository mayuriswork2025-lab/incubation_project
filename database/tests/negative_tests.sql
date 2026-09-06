-- ============================================================================
-- negative_tests.sql   |   Every statement here MUST FAIL.
-- ----------------------------------------------------------------------------
-- Run them ONE AT A TIME after 05_seed.sql. Each should raise an error naming
-- the constraint that stopped it. This is your review evidence that the
-- database enforces the business rules.
-- ============================================================================

-- (a) Rule 3 — a user cannot be in the same startup twice
--     (Sam is already a Member of EcoTrack)
insert into public.startup_memberships (startup_id, user_id, project_role)
values ((select startup_id from public.startups where startup_name = 'EcoTrack'),
        (select user_id   from public.users    where email = 'sam@test.com'), 'Member');
-- expect: duplicate key value violates unique constraint "memberships_unique_user_per_startup"


-- (b) project_role must be 'Founder' or 'Member'
insert into public.startup_memberships (startup_id, user_id, project_role)
values ((select startup_id from public.startups where startup_name = 'FinFlow'),
        (select user_id   from public.users    where email = 'priya@test.com'), 'CEO');
-- expect: violates check constraint "memberships_project_role_check"


-- (c) Rule 5 — a milestone must belong to a startup
insert into public.milestones (startup_id, milestone_name, due_date)
values (null, 'Orphan milestone', date '2026-12-01');
-- expect: null value in column "startup_id" violates not-null constraint


-- (d) completion_date is only allowed when status = 'Completed'
insert into public.milestones (startup_id, milestone_name, due_date, status, completion_date)
values ((select startup_id from public.startups where startup_name = 'FinFlow'),
        'Bad milestone', date '2026-12-01', 'Pending', date '2026-11-01');
-- expect: violates check constraint "milestones_completion_needs_completed_status"


-- (e) milestone status must be one of the three allowed values
insert into public.milestones (startup_id, milestone_name, due_date, status)
values ((select startup_id from public.startups where startup_name = 'FinFlow'),
        'Another bad one', date '2026-12-01', 'Done');
-- expect: violates check constraint "milestones_status_check"


-- (f) two milestones with the same name in the same startup
insert into public.milestones (startup_id, milestone_name, due_date)
values ((select startup_id from public.startups where startup_name = 'EcoTrack'),
        'MVP Launch', date '2026-12-01');
-- expect: violates unique constraint "milestones_unique_name_per_startup"


-- (g) a role that is in use cannot be deleted (on delete restrict)
delete from public.roles where role_name = 'Admin';
-- expect: update or delete on table "roles" violates foreign key constraint on "users"


-- (h) a startup name cannot be blank
insert into public.startups (startup_name) values ('   ');
-- expect: violates check constraint "startups_name_not_blank"


-- (i) email must be unique
update public.users set email = 'priya@test.com' where email = 'sam@test.com';
-- expect: duplicate key value violates unique constraint "users_email_unique"
