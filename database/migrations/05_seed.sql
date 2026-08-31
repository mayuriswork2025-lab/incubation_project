-- ============================================================================
-- 05_seed.sql   |   Realistic demo data for testing.  Safe to re-run.
-- ----------------------------------------------------------------------------
-- PREREQUISITE — create these 5 users first in Authentication -> Users -> Add user
-- (any password; the signup trigger creates their profile rows automatically):
--
--     admin@test.com   mentor@test.com   priya@test.com   arjun@test.com   sam@test.com
--
-- Then run this whole file.
-- ============================================================================

-- ---- clear any previous seed (children first; users are NOT touched) --------
delete from public.milestones;
delete from public.startup_memberships;
delete from public.startups;

-- ---- 1. flesh out the profiles: real names + system roles ------------------
update public.users set first_name = 'Aisha', last_name = 'Khan',
    role_id = (select role_id from public.roles where role_name = 'Admin')
    where email = 'admin@test.com';

update public.users set first_name = 'Ravi', last_name = 'Rao',
    role_id = (select role_id from public.roles where role_name = 'Mentor')
    where email = 'mentor@test.com';

update public.users set first_name = 'Priya', last_name = 'Sharma'
    where email = 'priya@test.com';        -- keeps default system role: Founder

update public.users set first_name = 'Arjun', last_name = 'Verma'
    where email = 'arjun@test.com';        -- Founder

update public.users set first_name = 'Sam', last_name = 'Lee'
    where email = 'sam@test.com';          -- Founder (system role) but only a Member below

-- ---- 2. startups ---------------------------------------------------------
insert into public.startups
    (startup_name, domain, description, registration_status, registered_by)
values
    ('EcoTrack', 'CleanTech', 'Carbon footprint tracker for small businesses', 'Approved',
        (select user_id from public.users where email = 'priya@test.com')),
    ('FinFlow',  'FinTech',   'Cash-flow forecasting for freelancers',          'Pending',
        (select user_id from public.users where email = 'arjun@test.com'));

-- ---- 3. memberships ----------------------------------------------------
-- EcoTrack: TWO co-founders (Priya + Arjun) and one member (Sam)
-- FinFlow : a single founder (Arjun)
insert into public.startup_memberships (startup_id, user_id, project_role)
values
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     (select user_id   from public.users    where email = 'priya@test.com'), 'Founder'),
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     (select user_id   from public.users    where email = 'arjun@test.com'), 'Founder'),
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     (select user_id   from public.users    where email = 'sam@test.com'),   'Member'),
    ((select startup_id from public.startups where startup_name = 'FinFlow'),
     (select user_id   from public.users    where email = 'arjun@test.com'), 'Founder');

-- ---- 4. milestones (one in each status) ------------------------------
insert into public.milestones
    (startup_id, milestone_name, description, due_date, status, completion_date)
values
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     'Prototype Demo', 'Working prototype shown to the cohort',
     date '2026-08-15', 'Completed', date '2026-08-14'),
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     'MVP Launch', 'Public MVP with 10 paying users',
     date '2026-10-15', 'In_Progress', null),
    ((select startup_id from public.startups where startup_name = 'EcoTrack'),
     'Seed Funding', 'Close a pre-seed round',
     date '2026-11-30', 'Pending', null),
    ((select startup_id from public.startups where startup_name = 'FinFlow'),
     'Beta Release', 'Invite-only beta',
     date '2026-12-01', 'Pending', null);

-- ---- 5. see the result ----------------------------------------------
select s.startup_name, s.registration_status,
       u.first_name || ' ' || u.last_name as person,
       sm.project_role
from public.startup_memberships sm
join public.startups s on s.startup_id = sm.startup_id
join public.users    u on u.user_id    = sm.user_id
order by s.startup_name, sm.project_role desc, person;

select s.startup_name, m.milestone_name, m.status,
       m.verification_status, m.due_date, m.completion_date
from public.milestones m
join public.startups s on s.startup_id = m.startup_id
order by s.startup_name, m.due_date;
