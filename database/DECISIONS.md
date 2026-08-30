# Design decisions — Incubator core module

A log of choices made while modelling `roles`, `users`, `startups`, `startup_memberships`, `milestones`.
Bring anything marked **(confirm with team)** to the group.

| # | Question | Decision | Why |
|---|----------|----------|-----|
| 1 | Table naming | All plural, lowercase, unquoted (`roles`, `users`, `startups`, `startup_memberships`, `milestones`) | Consistency; avoids the `"User"` reserved-word bug from the first attempt |
| 2 | One founder per startup, or many? **(confirm with team)** | One **or more**; at least one at all times | Real startups have co-founders |
| 3 | "System role" vs "project role" | System role (`users.role_id`) = Admin/Mentor/Founder/Judge, global. Project role (`startup_memberships.project_role`) = Founder/Member, per startup | Two different concepts; "member" is a per-startup relationship, not a system role |
| 4 | Who approves a startup (`Pending` → `Approved`)? **(confirm with team)** | Admin only | Incubator controls intake |
| 5 | Deleting a user | Soft delete (`status = 'Inactive'`). Hard delete requires transferring their founder roles first | Protects the "≥1 founder" rule; standard practice for user records |
| 6 | Duplicate startup names | Allowed | Different teams may reuse a name |
| 7 | `due_date` on a milestone | Required (`not null`) | A milestone with no deadline is meaningless |
| 8 | `registered_by` on a startup | Audit trail only, `on delete set null`. The authoritative founder(s) are the `'Founder'` membership rows | Keeps the startup if the creator's account is removed |
| 9 | Password storage | Never in our tables — Supabase Auth owns credentials in `auth.users` | Security; single source of truth |
| 10 | Surrogate keys | `bigint generated always as identity` (not `serial`); `users` keyed by the `auth.users` UUID | Modern SQL standard; ties profile to the login account |

## Rules enforced by table structure (scripts 01–03)
- Rule 1 — one system role per user → `users.role_id` NOT NULL FK
- Rule 3 — not in the same startup twice → `unique (user_id, startup_id)`
- Rule 4 — membership references a real user + startup → NOT NULL FKs
- Rule 5 — milestone belongs to one startup → `startup_id` NOT NULL FK
- Rule 9 (partial) — milestone status/verification values → CHECK constraints

## Rules enforced later by logic (scripts 06–08)
- Rule 2 — ≥1 founder always → `create_startup_with_founder()` + "last founder" guard
- Rule 6 — founders manage their own startup → RLS policies
- Rule 7 — members read-only → RLS policies
- Rule 8 — no self-promotion → guard trigger on `users`
- Rule 9 — only Mentor/Admin verify milestones → guard trigger on `milestones`
- Rule 10 — DB-level authorization → RLS on every table
