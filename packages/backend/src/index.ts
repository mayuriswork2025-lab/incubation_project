import cors from "cors";
import { sql } from "drizzle-orm";
import express from "express";
import { db } from "./db/client.js";
import { startup } from "./db/schema.js";

const app = express();
const port = process.env.PORT ?? 3001;

app.use(cors({ origin: "*" }));

app.get("/api/hello", (_req, res) => {
  res.json({ message: "Hello, world!" });
});

app.get("/api/startups", async (_req, res) => {
  try {
    const startups = await db.execute<typeof startup.$inferSelect>(sql`
      select
        "Startup_ID" as "startupId",
        "Startup_Name" as "startupName",
        "Domain" as "domain",
        "Description" as "description",
        "Registration_Date" as "registrationDate",
        "Registration_Status" as "registrationStatus",
        "Current_Stage" as "currentStage",
        "Registered_By" as "registeredBy"
      from "Startup"
    `);
    res.json(startups);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch startups" });
  }
});

app.listen(port, () => {
  console.log(`Backend listening on http://localhost:${port}`);
});
