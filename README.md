# Startup Incubator Management System

A full-stack application for managing startups, mentors, funding requests, milestones, and
demo day evaluations within a startup incubator program. Backend and frontend are both
TypeScript, backed by a [Supabase](https://supabase.com) (Postgres) database.

## Tech stack

| Layer      | Choice                                                          |
| ---------- | ---------------------------------------------------------------- |
| Database   | Supabase (Postgres + Auth + Row Level Security)                 |
| Migrations | Hand-written SQL, managed by the Supabase CLI                   |
| Query layer| [Drizzle ORM](https://orm.drizzle.team) (typed, lightweight, optional) |
| Backend    | Node.js + Express + TypeScript                                  |
| Frontend   | React + Vite + TypeScript                                       |
| Monorepo   | pnpm workspaces                                                  |

## Folder structure

```
.
├── packages/
│   ├── backend/            # Express API (TypeScript)
│   │   ├── src/
│   │   │   ├── db/
│   │   │   │   ├── client.ts   # Drizzle client (reads DATABASE_URL)
│   │   │   │   └── schema.ts   # Drizzle table definitions, mirrors the SQL migrations
│   │   │   └── index.ts        # Server entrypoint
│   │   └── drizzle.config.ts
│   └── frontend/           # React + Vite app (TypeScript)
│       └── src/
│           ├── lib/supabaseClient.ts
│           ├── App.tsx
│           └── main.tsx
├── db/
│   ├── config.toml         # Local Supabase stack config
│   ├── migrations/         # Numbered, hand-written SQL migrations (source of truth for schema)
│   └── seed.sql            # Local dev seed data, applied by `supabase db reset`
├── pnpm-workspace.yaml
└── package.json             # Root scripts that fan out to each package
```

Each package (`backend`, `frontend`) is self-contained with its own `package.json` and
`tsconfig.json`, so collaborators can work on one side without needing to understand the
other. Shared TypeScript compiler settings live in `tsconfig.base.json` at the root.

## Prerequisites

- Node.js 20+
- [pnpm](https://pnpm.io) (`corepack enable` will pick up the version pinned in `package.json`)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (used via `npx supabase`, no global install required)
- Docker (required by the Supabase CLI to run Postgres locally)

## Getting started

1. **Install dependencies**

   ```bash
   pnpm install
   ```

2. **Configure environment variables**

   ```bash
   cp .env.example .env
   ```

   Fill in `.env` with either your hosted Supabase project's credentials (Project Settings →
   API in the dashboard), or the local values printed by `supabase start` in the next step.

3. **Start the local Supabase stack** (Postgres, Auth, Studio)

   ```bash
   pnpm supabase:start
   ```

   This applies every migration in `db/migrations/` and then `db/seed.sql`
   automatically. Studio is available at `http://127.0.0.1:54323`.

4. **Run the backend and frontend** (in separate terminals)

   ```bash
   pnpm dev:backend
   pnpm dev:frontend
   ```

   - Backend: http://localhost:3001/api/hello
   - Frontend: http://localhost:3000

## Database migrations

Schema changes are made as plain SQL files under `db/migrations/`, applied in
filename order — these are the source of truth for the schema, not the Drizzle definitions.

- **Create a new migration:**

  ```bash
  pnpm db:new <migration_name>
  ```

  This creates a timestamped file under `db/migrations/`. Write your `CREATE TABLE`,
  `ALTER TABLE`, etc. by hand in that file.

- **Apply migrations locally** (drops and rebuilds the local DB from scratch, then re-seeds):

  ```bash
  pnpm db:reset
  ```

- **Push migrations to a hosted Supabase project:**

  ```bash
  pnpm db:push
  ```

- **After changing the schema**, update `packages/backend/src/db/schema.ts` to match, so the
  Drizzle types (used by the backend's query layer) stay in sync with the actual database.

### Using Drizzle

Drizzle is optional and only used as a typed query builder against the schema that the SQL
migrations define — it does not own migrations. See `packages/backend/src/db/client.ts` for
the client and `packages/backend/src/db/schema.ts` for table definitions.

```ts
import { db } from "./db/client.js";
import { role } from "./db/schema.js";

const roles = await db.select().from(role);
```

If you'd rather skip Drizzle for a given query, `@supabase/supabase-js` is also available in
both the backend and frontend for direct REST/RPC access to Supabase.

## Schema

The current schema (see `db/migrations/`) covers:

- `Role` — user roles (Admin, Mentor, Founder, Judge)
- `User` — platform users, linked 1:1 to Supabase `auth.users`
- `Startup` — registered startups
- `Startup_Membership` — many-to-many link between users and startups, with a project role
- `Milestone` — startup milestones with due dates, completion tracking, and mentor verification

Row Level Security is enabled on every table; policies restrict most access to admins and
members of the relevant startup. Mentor assignments, funding requests, and demo day
evaluations described in the original project scope are not yet modeled — add them as new
migrations under `db/migrations/` when that work starts.
