import { date, integer, pgTable, serial, text, uuid, varchar } from "drizzle-orm/pg-core";

/**
 * Source of truth for the DB schema. Change tables here, then run
 * `pnpm db:generate` to create a migration and `pnpm db:migrate` to apply it
 * (also runs automatically before `dev`/`start`).
 */

export const role = pgTable("Role", {
  roleId: serial("Role_ID").primaryKey(),
  roleName: varchar("Role_Name", { length: 50 }).notNull(),
  description: text("Description"),
});

export const user = pgTable("User", {
  userId: uuid("User_ID").primaryKey(),
  roleId: integer("Role_ID").notNull(),
  firstName: varchar("First_Name", { length: 50 }).notNull(),
  lastName: varchar("Last_Name", { length: 50 }).notNull(),
  email: varchar("Email", { length: 100 }).notNull(),
  phone: varchar("Phone", { length: 20 }),
  department: varchar("Department", { length: 100 }),
  registrationDate: date("Registration_Date"),
  status: varchar("Status", { length: 20 }),
});

export const startup = pgTable("Startup", {
  startupId: serial("Startup_ID").primaryKey(),
  startupName: varchar("Startup_Name", { length: 100 }).notNull(),
  domain: varchar("Domain", { length: 100 }),
  description: text("Description"),
  registrationDate: date("Registration_Date"),
  registrationStatus: varchar("Registration_Status", { length: 20 }),
  currentStage: varchar("Current_Stage", { length: 50 }),
  registeredBy: uuid("Registered_By"),
});

export const startupMembership = pgTable("Startup_Membership", {
  membershipId: serial("Membership_ID").primaryKey(),
  userId: uuid("User_ID").notNull(),
  startupId: integer("Startup_ID").notNull(),
  projectRole: varchar("Project_Role", { length: 50 }),
  joinDate: date("Join_Date"),
});

export const milestone = pgTable("Milestone", {
  milestoneId: serial("Milestone_ID").primaryKey(),
  startupId: integer("Startup_ID").notNull(),
  milestoneName: varchar("Milestone_Name", { length: 100 }).notNull(),
  dueDate: date("Due_Date"),
  completionDate: date("Completion_Date"),
  status: varchar("Status", { length: 20 }),
  verificationStatus: varchar("Verification_Status", { length: 20 }),
  mentorRemarks: text("Mentor_Remarks"),
});
