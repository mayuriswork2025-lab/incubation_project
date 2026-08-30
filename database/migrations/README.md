# Database migrations — Incubator module (roles, users, startups, memberships, milestones)

Run these **in order**, in the Supabase Dashboard → **SQL Editor** (paste → Run).

| # | File | Builds | Notes |
|---|------|--------|-------|
| 00 | `00_reset.sql` | — | ⚠️ One-time, destructive. Wipes old/duplicate tables. Also clear Auth → Users separately. |
| 01 | `01_roles_users.sql` | `roles`, `users`, signup trigger | Part 1 — identity |
| 02 | `02_startups_memberships.sql` | `startups`, `startup_memberships` | Part 2 — startups + founders/members |
| 03 | `03_milestones.sql` | `milestones` | Part 3 — deliverables |

Coming later:
- `04_updated_at.sql` — auto-maintain `updated_at`
- `05_seed.sql` — demo data for testing
- `06_policies.sql` — Row Level Security (who can read/write what)
- `07_guards.sql` — column rules (no self-promotion; only Mentor/Admin verify)
- `08_functions.sql` — business logic (create startup + founder atomically, status transitions)

## Conventions
- Table names are **plural**, lowercase, unquoted: `roles`, `users`, `startups`, `startup_memberships`, `milestones`.
- Column FK prefixes are singular: `user_id`, `startup_id`, `role_id`.
- Every table has `created_at` / `updated_at`.
- RLS is enabled on every table from creation; policies are added in `06`.
- Nothing changes the database without a script committed here first.

## For teammates (mentoring / funding / demo day modules)
Numbers `00`–`08` are reserved for this core module. Start your scripts at **`20_`**
onward (e.g. `20_mentoring.sql`, `30_funding.sql`, `40_demo_day.sql`) — coordinate
the exact numbers in the team channel.
Your tables link to `public.users(user_id)` and `public.startups(startup_id)`.
Do **not** create your own copies of those. Column names here are final after Day 4.
