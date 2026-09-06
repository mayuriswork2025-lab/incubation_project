-- ============================================================================
-- rls_test.sql   |   Verify the security layer (06 policies + 07 guards + 08 fns)
-- ----------------------------------------------------------------------------
-- Run AFTER 06, 07, 08 and after 05_seed.
-- Run ONE block at a time (select its lines -> Run). Compare the output to the
-- "EXPECT" comment. Every block is wrapped in begin/rollback, so nothing is
-- actually changed in the database.
-- ============================================================================


-- ========== SANITY — does impersonation work? ==============================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  select public.current_user_role() as role_should_be_Founder,
         (select auth.uid())        as uid_should_not_be_null;
  reset role;
rollback;
-- EXPECT: role = 'Founder', uid = a UUID.  If both are null, tell Claude — your
-- Supabase reads a different JWT setting and the tests below need adjusting.


-- ========== B1 — a Member can READ their startup ===========================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='sam@test.com'), true);
  set local role authenticated;
  select startup_name from public.startups where startup_name = 'EcoTrack';
  reset role;
rollback;
-- EXPECT: 1 row (Sam is a member of EcoTrack)


-- ========== B2 — a Member CANNOT update their startup (Rule 7) =============
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='sam@test.com'), true);
  set local role authenticated;
  update public.startups set description = 'changed by Sam' where startup_name = 'EcoTrack';
  reset role;
rollback;
-- EXPECT: UPDATE 0   (member has no write access)


-- ========== B3 — a Founder CAN update their startup (Rule 6) ==============
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  update public.startups set description = 'changed by Priya' where startup_name = 'EcoTrack';
  reset role;
rollback;
-- EXPECT: UPDATE 1


-- ========== B4 — a non-member cannot even SEE the startup ================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='sam@test.com'), true);
  set local role authenticated;
  select startup_name from public.startups where startup_name = 'FinFlow';
  reset role;
rollback;
-- EXPECT: 0 rows   (Sam is not in FinFlow)


-- ========== B5 — Admin sees everything ==================================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='admin@test.com'), true);
  set local role authenticated;
  select count(*) as startups_visible from public.startups;
  reset role;
rollback;
-- EXPECT: 2


-- ========== C1 — you CANNOT promote yourself (Rule 8) ===================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  update public.users
     set role_id = (select role_id from public.roles where role_name = 'Admin')
   where user_id = (select auth.uid());
  reset role;
rollback;
-- EXPECT: ERROR — "You cannot change your own role (business rule 8)"


-- ========== C2 — a Founder CANNOT verify a milestone (Rule 9) ===========
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  update public.milestones set verification_status = 'Verified'
   where milestone_name = 'Prototype Demo';
  reset role;
rollback;
-- EXPECT: ERROR — "Only a Mentor or Admin can verify a milestone"


-- ========== C3 — a Mentor CAN verify a milestone =======================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='mentor@test.com'), true);
  set local role authenticated;
  update public.milestones set verification_status = 'Verified'
   where milestone_name = 'Prototype Demo';
  reset role;
rollback;
-- EXPECT: UPDATE 1


-- ========== C4 — milestone status cannot go backwards (Rule 9) =========
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  update public.milestones set status = 'Pending' where milestone_name = 'Prototype Demo';
  reset role;
rollback;
-- EXPECT: ERROR — "status cannot go from Completed to Pending"


-- ========== D1 — a Founder creates a startup atomically (Rule 2) =======
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  select startup_id, startup_name, registration_status
  from public.create_startup_with_founder('NovaAI', 'AI', 'test startup');
  reset role;
rollback;
-- EXPECT: 1 row. (Priya is auto-added as its Founder — rolled back after.)


-- ========== D2 — a Member cannot add members ==========================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='sam@test.com'), true);
  set local role authenticated;
  select public.add_startup_member(
    (select startup_id from public.startups where startup_name='EcoTrack'),
    (select user_id    from public.users    where email='admin@test.com'));
  reset role;
rollback;
-- EXPECT: ERROR — "Only a founder of this startup (or an Admin) can add members"


-- ========== D3 — cannot remove the last founder (Rule 2) ==============
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='arjun@test.com'), true);
  set local role authenticated;
  select public.remove_startup_member(
    (select startup_id from public.startups where startup_name='FinFlow'),
    (select user_id    from public.users    where email='arjun@test.com'));
  reset role;
rollback;
-- EXPECT: ERROR — "A startup must keep at least one founder (business rule 2)"


-- ========== D4 — a non-Admin cannot approve a startup =================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='priya@test.com'), true);
  set local role authenticated;
  select public.set_startup_status(
    (select startup_id from public.startups where startup_name='FinFlow'), 'Approved');
  reset role;
rollback;
-- EXPECT: ERROR — "Only an Admin can approve or reject a startup"


-- ========== D5 — an Admin CAN approve a startup ======================
begin;
  select set_config('request.jwt.claims',
    (select json_build_object('sub', user_id)::text from public.users where email='admin@test.com'), true);
  set local role authenticated;
  select startup_name, registration_status
  from public.set_startup_status(
    (select startup_id from public.startups where startup_name='FinFlow'), 'Approved');
  reset role;
rollback;
-- EXPECT: 1 row, registration_status = 'Approved'
