# Action Plan — Core module → Review 2

Branch: `mayuri_module`   |   Started: 2026-08-31

**Key:**  🧑 = you do it in Supabase   ·   🤖 = Claude provides the script   ·   ✅ = commit + push checkpoint

Current state: tables `01`–`03` built & verified in Supabase. Scripts `04`, `05`, `negative_tests.sql` written, not yet run.

---

## Phase A — Finish the data layer   (Day 4, ~45 min)

- [ ] **A1** 🧑 Run `04_updated_at.sql` → expect 5 trigger rows
- [ ] **A2** 🧑 Authentication → Add user ×5 (password `Test1234!`):
      `admin@test.com  mentor@test.com  priya@test.com  arjun@test.com  sam@test.com`
      then `select email, role_id from public.users order by email;` → 6 rows
- [ ] **A3** 🧑 Run `05_seed.sql` → EcoTrack shows 2 Founders + 1 Member; 4 milestones in 3 statuses
- [ ] **A4** 🧑 Run `negative_tests.sql` **one statement at a time**; copy each error message
- [ ] **A5** 🧑 Save the 9 error messages as `database/tests/negative_results.md`
- [ ] ✅ commit: `git add -A && git commit -m "Day 4: data layer verified" && git push`

**Done when:** all 9 negative tests fail with a named constraint; seed data visible.

---

## Phase B — Security: Row Level Security   (Days 5–6)

- [ ] **B1** 🤖 Claude provides `06_policies.sql`
      (helper functions `is_admin` / `current_user_role` / `is_startup_member` / `is_startup_founder`
       + SELECT/INSERT/UPDATE/DELETE policies for all 5 tables)
- [ ] **B2** 🧑 Run it → `select tablename, policyname, cmd from pg_policies where schemaname='public' order by 1,3;` → ~18–20 rows
- [ ] **B3** 🤖 Claude provides `database/tests/rls_test.sql` — impersonates each seeded user with
      `begin; set local request.jwt.claims = '{"sub":"<uuid>"}'; <query>; rollback;`
- [ ] **B4** 🧑 Run the access-matrix checks. Every result must match "expected":

      | Actor | Action | Expected |
      |-------|--------|----------|
      | Sam (member)   | update EcoTrack | denied |
      | Priya (founder)| update EcoTrack | allowed |
      | Sam            | read EcoTrack milestones | allowed |
      | Sam            | read FinFlow (not a member) | 0 rows |
      | Arjun          | read FinFlow (founder) | rows |
      | any member     | delete a startup | denied |

- [ ] **B5** 🧑 Save output as `database/tests/rls_results.md`
- [ ] ✅ commit + push

**Done when:** the access matrix is 100% green. This is Business Rules 6, 7, 10.

---

## Phase C — Column guards (triggers)   (Day 7)

- [ ] **C1** 🤖 Claude provides `07_guards.sql`:
      - `users`: block self-change of `role_id` / `status` (unless Admin)  → Rule 8
      - `milestones`: block non-Mentor/Admin editing `verification_status` / `mentor_remarks`  → Rule 9
      - `milestones`: block illegal status jumps (e.g. Completed → Pending)  → Rule 9
- [ ] **C2** 🧑 Run it
- [ ] **C3** 🧑 Test (Claude adds cases to `rls_test.sql`):
      - Priya sets her own `role_id` = Admin → denied
      - Priya (founder) sets milestone `verification_status` = 'Verified' → denied
      - Ravi (mentor) sets `verification_status` = 'Verified' → allowed
      - milestone Completed → Pending → denied
- [ ] **C4** 🧑 Save results
- [ ] ✅ commit + push

---

## Phase D — Business functions (RPC)   (Days 8–9)

- [ ] **D1** 🤖 Claude provides `08_functions.sql`:
      - `create_startup_with_founder(name, domain, description)` — atomic → Rule 2
      - `add_startup_member(startup_id, user_id)` / `remove_startup_member(...)` — blocks removing last founder
      - `promote_to_founder(startup_id, user_id)`
      - `set_milestone_status(milestone_id, new_status)` — forward-only, auto completion_date
      - `approve_startup(startup_id)` — Admin only
      - `assign_user_role(user_id, role_name)` — Admin only
- [ ] **D2** 🧑 Run it
- [ ] **D3** 🧑 Test:
      - Priya `create_startup_with_founder('NewCo')` → startup + her founder row both created
      - Sam (member) `add_startup_member(...)` → denied
      - remove the only founder of FinFlow → denied
      - non-admin `approve_startup(...)` → denied
- [ ] **D4** 🧑 Save results
- [ ] ✅ commit + push

---

## Phase E — Review artifacts   (Day 10)

- [ ] **E1** 🤖 `database/ER_v2.md` — the 5 tables as built (mermaid diagram + notes)
- [ ] **E2** 🤖 `database/TRACEABILITY.md` — 10 business rules × the exact mechanism enforcing each
- [ ] **E3** 🤖 `database/DEMO.md` — click-by-click live demo script (Priya edits milestone = works; Sam tries = blocked)
- [ ] **E4** 🧑 Rehearse the demo 2–3 times
- [ ] ✅ Final commit + push. Open PR: `mayuri_module` → `main`

---

## What you present at Review 2
1. ER v2 diagram (matches the live DB)
2. Traceability table (rules → enforcement)
3. Live demo — the database blocking a Member, not the UI
4. Negative-test log (constraints + guards rejecting bad input)
5. Numbered migration scripts in the repo

## Session rhythm
Each session: pull → run the day's script(s) → run the tests → paste results to Claude → commit + push.
If a test fails unexpectedly: stop, paste the error, don't run the next script.

## Still open (team)
- Confirm the 5 core tables are yours alone to build.
- Warn teammate about the `main` force-push (2026-08-30).
