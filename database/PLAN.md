# Backend Plan — Incubator Core Module

**Owner:** core 5 tables (`roles`, `users`, `startups`, `startup_memberships`, `milestones`)
**Branch:** `mayuri_module`   ·   **Target:** Review 2 (~1–2 weeks from 2026-08-30)
**Stack:** Supabase (Postgres + Auth + PostgREST), migrations = numbered `.sql` files run in the SQL Editor.

**Key:**  🧑 you do it in Supabase  ·  🤖 Claude provides the script  ·  ✅ commit + push

---

## 1. Current status (2026-08-31)

| Item | State |
|---|---|
| Supabase project | wiped clean, rebuilt from scratch |
| `01_roles_users.sql` | ✅ applied + verified (4 roles, signup trigger works) |
| `02_startups_memberships.sql` | ✅ applied + verified |
| `03_milestones.sql` | ✅ applied + verified (5 tables, RLS on, all FKs correct) |
| `04_updated_at.sql` | written, **not run** |
| `05_seed.sql` | written, **not run** |
| `tests/negative_tests.sql` | written, **not run** |
| `06_policies.sql` / `07_guards.sql` / `08_functions.sql` | not written yet |

---

## 2. Design decisions

| # | Question | Decision | Why |
|---|----------|----------|-----|
| 1 | Table naming | all plural, lowercase, unquoted; FK columns singular (`user_id`) | consistency; avoids the `"User"` reserved-word bug |
| 2 | One founder per startup, or many? | **one or more; at least one always** | real startups have co-founders |
| 3 | "system role" vs "project role" | system role (`users.role_id`: Admin/Mentor/Founder/Judge, global) ≠ project role (`startup_memberships.project_role`: Founder/Member, per startup). A "member" is a membership row, not a system role. | two different concepts |
| 4 | Who approves a startup? | Admin only | incubator controls intake |
| 5 | Deleting a user | soft delete (`status = 'Inactive'`); hard delete needs founder transfer first | protects the "≥1 founder" rule |
| 6 | Duplicate startup names | allowed | different teams may reuse a name |
| 7 | `due_date` on a milestone | required | a milestone with no deadline is meaningless |
| 8 | `registered_by` on a startup | audit only, `on delete set null`; real founders = the `'Founder'` membership rows | keep the startup if the creator leaves |
| 9 | Password storage | never in our tables — Supabase Auth owns credentials | security, single source of truth |
| 10 | Surrogate keys | `bigint generated always as identity`; `users` keyed by the `auth.users` UUID | modern SQL standard |

---

## 3. The 5 tables

```
roles ──1:N──> users ──1:N──> startup_memberships ──N:1──> startups ──1:N──> milestones
 (Admin/Mentor/           (junction: project_role         ▲
  Founder/Judge)           = Founder | Member)   registered_by (audit)
```

- **roles** — 4 system roles, `role_name` unique
- **users** — profile, PK = auth UUID, one `role_id` (required), no password, `status` ∈ {Active, Inactive, Suspended}
- **startups** — `registration_status` ∈ {Pending, Approved, Rejected}, `registered_by` → users (set null)
- **startup_memberships** — `project_role` ∈ {Founder, Member}, `unique(user_id, startup_id)`, ≥1 founder (kept by functions)
- **milestones** — `startup_id` required (cascade), `status` ∈ {Pending, In_Progress, Completed}, `verification_status` ∈ {Unverified, Verified, Rejected}, `completion_date` only when Completed, `unique(startup_id, milestone_name)`

---

## 4. Business rules → where each is enforced

| Rule | Mechanism | Status |
|---|---|---|
| 1 — one system role per user | `users.role_id` NOT NULL FK → `roles` | ✅ done |
| 2 — one *or more* founders, always ≥1 | `create_startup_with_founder()` + "last founder" guard | ⏳ Phase D |
| 3 — not in same startup twice | `unique (user_id, startup_id)` | ✅ done |
| 4 — membership references real user + startup | NOT NULL FKs | ✅ done |
| 5 — milestone belongs to one startup | `startup_id` NOT NULL FK | ✅ done |
| 6 — founders manage their own startup | RLS policies + `is_startup_founder()` | ⏳ Phase B |
| 7 — members read-only | RLS policies (SELECT only for members) | ⏳ Phase B |
| 8 — no self-promotion | guard trigger on `users` (block own `role_id`/`status` change) | ⏳ Phase C |
| 9 — milestone statuses controlled | CHECK constraints ✅ + guard trigger (verify = Mentor/Admin only; forward-only transitions) ⏳ | partial |
| 10 — DB-level authorization | RLS enabled on all 5 ✅ + full policy set ⏳ | partial |

---

## 5. Phases

### Phase A — Finish the data layer   (Day 4, ~45 min)
- [ ] 🧑 Run `04_updated_at.sql` → expect 5 trigger rows
- [ ] 🧑 Authentication → Add user ×5 (password `Test1234!`): `admin@ mentor@ priya@ arjun@ sam@` `test.com`
      → `select email, role_id from public.users order by email;` → 6 rows
- [ ] 🧑 Run `05_seed.sql` → EcoTrack: 2 Founders + 1 Member; 4 milestones across 3 statuses
- [ ] 🧑 Run `tests/negative_tests.sql` **one statement at a time**; copy each error
- [ ] 🧑 Save the 9 errors as `database/tests/negative_results.md`
- [ ] ✅ commit: "Day 4: data layer verified"

**Done when:** all 9 negative tests fail with a named constraint.

### Phase B — Security: Row Level Security   (Days 5–6)
- [ ] 🤖 `06_policies.sql` — helper functions (`is_admin`, `current_user_role`, `is_startup_member`, `is_startup_founder`) + SELECT/INSERT/UPDATE/DELETE policies for all 5 tables:

      | table | SELECT | INSERT | UPDATE | DELETE |
      |-------|--------|--------|--------|--------|
      | roles | any logged-in | Admin | Admin | Admin |
      | users | any logged-in | (trigger only) | self or Admin | Admin |
      | startups | members + Admin | any Founder-role | that startup's founders + Admin | founders + Admin |
      | startup_memberships | co-members + Admin | founders + Admin | founders + Admin | founders + Admin |
      | milestones | members + Admin | founders + Admin | founders / assigned Mentor / Admin | founders + Admin |

- [ ] 🧑 Run it → `select tablename, policyname, cmd from pg_policies where schemaname='public' order by 1,3;` → ~18–20 rows
- [ ] 🤖 `tests/rls_test.sql` — impersonates each user:
      ```sql
      begin;
        set local request.jwt.claims = '{"sub":"<user-uuid>"}';
        <query>;
      rollback;
      ```
- [ ] 🧑 Run the access matrix — every result matches expected:

      | Actor | Action | Expected |
      |-------|--------|----------|
      | Sam (member)    | update EcoTrack           | denied  |
      | Priya (founder) | update EcoTrack           | allowed |
      | Sam             | read EcoTrack milestones  | allowed |
      | Sam             | read FinFlow (not member) | 0 rows  |
      | Arjun (founder) | read FinFlow              | rows    |
      | any member      | delete a startup          | denied  |

- [ ] 🧑 Save as `database/tests/rls_results.md`
- [ ] ✅ commit

**Done when:** access matrix is 100% green (Rules 6, 7, 10).

### Phase C — Column guards (triggers)   (Day 7)
- [ ] 🤖 `07_guards.sql`:
      - `users`: block self-change of `role_id` / `status` unless Admin  → Rule 8
      - `milestones`: block non-Mentor/Admin editing `verification_status` / `mentor_remarks`  → Rule 9
      - `milestones`: block illegal status jumps (Completed → Pending)  → Rule 9
- [ ] 🧑 Run it
- [ ] 🧑 Test:
      - Priya sets her own `role_id` = Admin → denied
      - Priya (founder) sets milestone `verification_status` = 'Verified' → denied
      - Ravi (mentor) sets `verification_status` = 'Verified' → allowed
      - milestone Completed → Pending → denied
- [ ] 🧑 Save results
- [ ] ✅ commit

### Phase D — Business functions (RPC)   (Days 8–9)
- [ ] 🤖 `08_functions.sql`:
      - `create_startup_with_founder(name, domain, description)` — atomic → Rule 2
      - `add_startup_member(startup_id, user_id)` / `remove_startup_member(...)` — blocks removing last founder
      - `promote_to_founder(startup_id, user_id)`
      - `set_milestone_status(milestone_id, new_status)` — forward-only, auto `completion_date`
      - `approve_startup(startup_id)` — Admin only
      - `assign_user_role(user_id, role_name)` — Admin only
- [ ] 🧑 Run it
- [ ] 🧑 Test:
      - Priya `create_startup_with_founder('NewCo')` → startup + her founder row both created
      - Sam (member) `add_startup_member(...)` → denied
      - remove the only founder of FinFlow → denied
      - non-admin `approve_startup(...)` → denied
- [ ] 🧑 Save results
- [ ] ✅ commit

### Phase E — Review artifacts   (Day 10)
- [ ] 🤖 `database/ER_v2.md` — the 5 tables as built (mermaid diagram + notes)
- [ ] 🤖 `database/TRACEABILITY.md` — section 4 of this file, finalised with evidence
- [ ] 🤖 `database/DEMO.md` — click-by-click live demo (Priya edits milestone = works; Sam tries = blocked)
- [ ] 🧑 Rehearse the demo 2–3 times
- [ ] ✅ Final commit + push. Open PR: `mayuri_module` → `main`

---

## 6. What to present at Review 2
1. **ER v2** — diagram matching the live DB
2. **Traceability table** — 10 rules × the exact mechanism (section 4)
3. **Live demo** — the database blocking a Member, not the UI
4. **Negative-test log** — constraints + guards rejecting bad input
5. **Migration scripts** — numbered, in order, in the repo

## 7. Session rhythm
Pull → run the day's script(s) → run the tests → paste results to Claude → commit + push.
If a test fails unexpectedly: stop, paste the error, don't run the next script.

## 8. Open (team)
- Confirm the 5 core tables are yours alone to build.
- Warn teammate about the `main` force-push (2026-08-30): if they pulled `main`, they must
  `git checkout main && git fetch origin && git reset --hard origin/main`.
