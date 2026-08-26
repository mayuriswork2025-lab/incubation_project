-- Local dev seed data.
-- Role reference data already ships in the init migration, so this file only seeds
-- Startup/Startup_Membership/Milestone rows, which depend on a real auth.users row
-- (the User table's FK to auth.users). That row only exists once someone signs up
-- through Supabase Auth (e.g. Dashboard > Authentication > Add user) — the
-- on_auth_user_created trigger then auto-creates the matching "User" row for you.
--
-- Run with the founder's UUID passed in as a psql variable:
--   psql "$DATABASE_URL" -v founder_id="'<user-uuid>'" -f db/seed.sql

insert into "Startup" (Startup_Name, Domain, Description, Registration_Status, Current_Stage, Registered_By)
  values ('EcoTrack', 'CleanTech', 'Carbon footprint tracker for SMEs', 'Approved', 'MVP', :founder_id)
  returning "Startup_ID" as founder_startup_id \gset

insert into "Startup_Membership" (User_ID, Startup_ID, Project_Role)
  values (:founder_id, :founder_startup_id, 'Founder');

insert into "Milestone" (Startup_ID, Milestone_Name, Due_Date, Status, Verification_Status)
  values (:founder_startup_id, 'MVP Launch', '2026-09-30', 'In_Progress', 'Unverified');

insert into "Milestone" (Startup_ID, Milestone_Name, Due_Date, Completion_Date, Status, Verification_Status, Mentor_Remarks)
  values (:founder_startup_id, 'Idea Validation', '2026-07-15', '2026-07-10', 'Completed', 'Verified', 'Solid early customer interviews, proceed to MVP.');
