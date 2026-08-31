# TODO — 2026-08-31  (branch: mayuri_module)

Goal today: get the 5 core tables built and verified in Supabase.

## 1. Coordinate with the team (do this first)
- [ ] Message **mayuriswork2025-lab**: confirm the 5 core tables
      (`roles`, `users`, `startups`, `startup_memberships`, `milestones`)
      are mine to build — they also pushed a `00_reset.sql`.
- [ ] Warn them about the `main` force-push yesterday: if they pulled `main`,
      they must run `git checkout main && git fetch origin && git reset --hard origin/main`.
- [ ] Confirm **revised Rule 2** with the team: a startup has *one or more*
      founders, always at least one.

## 2. Run the migrations — Supabase → SQL Editor, in order
- [ ] `01_roles_users.sql`  → expect 4 rows: Admin, Mentor, Founder, Judge
- [ ] Test the signup trigger:
      Authentication → Users → Add user (any test email + password), then run
      `select user_id, role_id, first_name, email from public.users;`
      → expect 1 row, `role_id` = the Founder id
- [ ] `02_startups_memberships.sql`  → expect `startups 0` / `startup_memberships 0`
- [ ] `03_milestones.sql`  → expect `milestones 0`
- [ ] If any script errors: STOP, copy the error, do not run the next one.

## 3. Verify the structure
- [ ] Table Editor: all 5 tables present with the expected columns
- [ ] RLS shows enabled (lock icon) on all 5 tables
- [ ] Run and skim the constraint list:
      ```sql
      select table_name, constraint_type, constraint_name
      from information_schema.table_constraints
      where table_schema = 'public'
      order by table_name, constraint_type;
      ```

## 4. Report back
- [ ] Paste the check output from each script → then start Day 4.

## 5. If time permits — start Day 4 (test data)
- [ ] Sketch realistic sample data on paper: 3–4 users, 2 startups
      (one with co-founders), a few members, milestones in different statuses.
      Trying to enter it is what exposes any remaining logic gap.
