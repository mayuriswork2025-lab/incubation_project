# Backend Handover — How to Finish the Project

**From:** Harish · **Date:** 2026-09-06
**Stack:** Supabase only. Postgres tables + Row Level Security + SQL functions. **No separate API** — Supabase turns the database into the API automatically.

Before you start, read `database/README.md`. It shows the 5 tables that are already
built and how they work. Your new tables plug into those.

---

## 1. What is done, what is left

**Done (Harish) — the 5 core tables and everything around them:**
`roles`, `users`, `startups`, `startup_memberships`, `milestones` — with security,
rules, helper functions, test data, and tests. All live on Supabase. Scripts `00`–`08`.

**Left — 6 more tables, in 3 groups:**

| Group | Tables | Suggested script name |
|---|---|---|
| A. Mentoring | `mentor_requests`, `mentor_assignments`, `meetings` | `20_mentoring.sql` |
| B. Funding | `funding_requests` | `30_funding.sql` |
| C. Demo day | `demo_days`, `evaluations` | `40_demo_day.sql` |

Each group is one person's job. Mentoring is the biggest — start it first.

---

## 2. The 6 tables you need to build

Use the **same style as the first 5**: plural lowercase names, `bigint generated always as
identity` for the id, `created_at` and `updated_at` on every table, and **always** link to
`users(user_id)` and `startups(startup_id)` — never make your own copy of those.

### A. Mentoring

**`mentor_requests`** — a startup asks for a mentor
- `mentor_request_id` — id
- `startup_id` → startups, NOT NULL, on delete cascade
- `requested_by` → users, NOT NULL  (a founder of that startup)
- `required_skills` — text
- `request_description` — text
- `status` — text, default `'Pending'`, CHECK in (`Pending`, `Approved`, `Rejected`)
- `decided_by` → users, on delete set null  (the Admin who decided)
- `decision_date` — date
- `remarks` — text

**`mentor_assignments`** — an approved request gets a mentor
- `assignment_id` — id
- `mentor_request_id` → mentor_requests, NOT NULL, on delete cascade
- `mentor_id` → users, NOT NULL  (someone whose role is Mentor)
- `assigned_date` — date, default today
- `end_date` — date
- `status` — text, default `'Active'`, CHECK in (`Active`, `Completed`, `Cancelled`)
- UNIQUE (`mentor_request_id`, `mentor_id`)

**`meetings`** — mentor and startup meet
- `meeting_id` — id
- `assignment_id` → mentor_assignments, NOT NULL, on delete cascade
- `meeting_date` — date, NOT NULL
- `meeting_time` — time
- `agenda`, `discussion`, `action_items` — text
- `status` — text, default `'Scheduled'`, CHECK in (`Scheduled`, `Completed`, `Cancelled`)

### B. Funding

**`funding_requests`**
- `funding_request_id` — id
- `startup_id` → startups, NOT NULL, on delete cascade
- `requested_amount` — numeric(12,2), NOT NULL, CHECK > 0
- `purpose` — text
- `status` — text, default `'Pending'`, CHECK in (`Pending`, `Approved`, `Rejected`)
- `approved_amount` — numeric(12,2), CHECK: null unless status is `Approved`
- `decided_by` → users, on delete set null  (Admin)
- `decision_date` — date
- `remarks` — text

### C. Demo day

**`demo_days`**
- `demo_day_id` — id
- `event_name` — text, NOT NULL, not blank
- `event_date` — date, NOT NULL
- `venue` — text

**`evaluations`** — a judge scores a startup
- `evaluation_id` — id
- `demo_day_id` → demo_days, NOT NULL, on delete cascade
- `startup_id` → startups, NOT NULL, on delete cascade
- `judge_id` → users, NOT NULL  (someone whose role is Judge)
- `innovation_score`, `technical_score`, `business_score`, `presentation_score`
  — numeric(4,2), CHECK between 0 and 10
- `overall_remarks` — text
- UNIQUE (`demo_day_id`, `startup_id`, `judge_id`)  — one score sheet per judge per startup

---

## 3. Build steps — do ALL of these for your group (not just the table)

This is exactly what Harish did for the first 5. Do the same 7 steps. Each step = add to your
one script file, paste it into the Supabase **SQL Editor**, Run, check it worked, then commit.

### Step 1 — Create the tables
- Columns, types, `NOT NULL` where needed.
- A `CHECK` for every status-type column (see the lists above).
- A `UNIQUE` for anything that must not repeat.
- Every foreign key gets `on delete cascade` / `set null` / `restrict` — decide which.
- Add an index on each foreign key column: `create index idx_<table>_<col> on public.<table> (<col>);`
- Turn on security: `alter table public.<table> enable row level security;`
- *Copy the style from* `migrations/01_roles_users.sql` and `03_milestones.sql`.

### Step 2 — Auto-update `updated_at`
For each new table, add:
```sql
create trigger trg_<table>_updated_at
  before update on public.<table>
  for each row execute function public.set_updated_at();
```
(`set_updated_at()` already exists — Harish made it. Just reuse it.)

### Step 3 — Add test data (seed)
Insert 2–4 realistic rows per table, using the users and startups that already exist
(`priya@test.com`, `EcoTrack`, etc. — see `README.md` §7).
*Copy the style from* `migrations/05_seed.sql`.

### Step 4 — Row Level Security (who can see / change what)
Add 4 policies per table: `select`, `insert`, `update`, `delete`.
Reuse Harish's helper functions inside them:
- `public.is_admin()` — is the current user an Admin?
- `public.current_user_role()` — returns `'Mentor'`, `'Judge'`, etc.
- `public.is_startup_member(startup_id)` — is the current user in that startup?
- `public.is_startup_founder(startup_id)` — is the current user a founder of it?

Typical rules:
- A **founder** of the startup can create/see its mentor requests and funding requests.
- The **assigned mentor** can see and edit their own assignment and its meetings.
- A **judge** can only add/edit their **own** evaluations.
- **Admin** can do everything.
- Everyone else: no access.

*Copy the style from* `migrations/06_policies.sql`.

### Step 5 — Guard triggers (rules a policy can't do)
Only add these where needed. Examples:
- Block changing `status` from `Approved`/`Rejected` back to `Pending` (no re-deciding).
- Only an Admin may set `funding_requests.status` to `Approved`/`Rejected`.
- A `mentor_assignments.mentor_id` must belong to a user whose role is `Mentor`.
- No new evaluations after the demo day date has passed.

*Copy the style from* `migrations/07_guards.sql`.

### Step 6 — Business functions (multi-step actions)
Write a SQL function for anything that touches more than one table or needs a permission check.
Suggested:
- `approve_mentor_request(request_id, mentor_id)` — set the request to Approved **and** create
  the assignment, in one go. Admin only.
- `decide_funding_request(funding_id, approved_amount, remarks)` — Admin only.
- `submit_evaluation(demo_day_id, startup_id, scores...)` — Judge only, one per startup.

Make them `security definer`, check the caller's role at the top, `revoke` from public and
`grant execute ... to authenticated`.
*Copy the style from* `migrations/08_functions.sql`.

### Step 7 — Tests (proof for the review)
Two test files in `tests/`:
- `tests/<group>_negative.sql` — bad inserts that **must fail** (wrong status value, score of 50,
  duplicate evaluation, etc.). Copy `tests/negative_tests.sql`.
- `tests/<group>_rls.sql` — log in as each kind of user and check they can/can't do things.
  Copy `tests/rls_test.sql`.

Run every test, and **save the results** (paste the pass/fail outcomes into the file as comments,
or a short `tests/<group>_results.md`).

**Tip for the SQL Editor:** when a test does an `UPDATE` and you want to see how many rows changed,
wrap it like this so the number actually shows:
```sql
with u as ( update ... where ... returning 1 )
select count(*) from u;
```

---

## 4. Update the shared docs when you're done

In `database/README.md`:
- **§1** — add your tables to the ER diagram (the `mermaid` block).
- **§3** — add your business rules to the traceability table (rules 11+).
- **§5** — add your new table endpoints and function endpoints to the API reference
  (Supabase exposes them automatically once RLS is set — just list them).

---

## 5. Rules for working together

- **Commit the script before you run it** on Supabase. Tell the group in the channel when you apply one.
- Script numbers: `20_` mentoring, `30_` funding, `40_` demo day, `50_` any combined seed/checks.
- **Do not change** the 5 core tables, scripts `00`–`08`, the helper functions, or the test accounts.
  If the core is blocking you, message Harish.

---

## 6. Final check (all of us, after the 6 tables are done)

- [ ] All 11 tables exist, security on, all foreign keys have an `on delete` rule
- [ ] Every group has: seed data + negative tests + RLS tests, with saved results
- [ ] `README.md` ER diagram, traceability table, and API list cover all 11 tables
- [ ] Fresh run works: new Supabase project → `00`→`08`→`20`→`30`→`40`→seed, no errors
- [ ] Demo rehearsed: for each module, show the database blocking bad data / the wrong user
- [ ] All committed, PR opened and merged to `main`
