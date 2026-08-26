import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.js";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL is not set. Copy .env.example to .env and fill it in.");
}

const founderId = process.argv.slice(2).find((arg) => arg !== "--");
if (!founderId) {
  throw new Error("Usage: pnpm db:seed -- <founder-user-uuid>");
}

const client = postgres(connectionString, { max: 1 });
const db = drizzle(client, { schema });

const [startup] = await db
  .insert(schema.startup)
  .values({
    startupName: "EcoTrack",
    domain: "CleanTech",
    description: "Carbon footprint tracker for SMEs",
    registrationStatus: "Approved",
    currentStage: "MVP",
    registeredBy: founderId,
  })
  .returning({ startupId: schema.startup.startupId });

await db.insert(schema.startupMembership).values({
  userId: founderId,
  startupId: startup.startupId,
  projectRole: "Founder",
});

await db.insert(schema.milestone).values([
  {
    startupId: startup.startupId,
    milestoneName: "MVP Launch",
    dueDate: "2026-09-30",
    status: "In_Progress",
    verificationStatus: "Unverified",
  },
  {
    startupId: startup.startupId,
    milestoneName: "Idea Validation",
    dueDate: "2026-07-15",
    completionDate: "2026-07-10",
    status: "Completed",
    verificationStatus: "Verified",
    mentorRemarks: "Solid early customer interviews, proceed to MVP.",
  },
]);

console.log(`Seeded Startup #${startup.startupId} for founder ${founderId}`);
await client.end();
