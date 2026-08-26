CREATE TABLE IF NOT EXISTS "Milestone" (
	"Milestone_ID" serial PRIMARY KEY NOT NULL,
	"Startup_ID" integer NOT NULL,
	"Milestone_Name" varchar(100) NOT NULL,
	"Due_Date" date,
	"Completion_Date" date,
	"Status" varchar(20),
	"Verification_Status" varchar(20),
	"Mentor_Remarks" text
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "Role" (
	"Role_ID" serial PRIMARY KEY NOT NULL,
	"Role_Name" varchar(50) NOT NULL,
	"Description" text
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "Startup" (
	"Startup_ID" serial PRIMARY KEY NOT NULL,
	"Startup_Name" varchar(100) NOT NULL,
	"Domain" varchar(100),
	"Description" text,
	"Registration_Date" date,
	"Registration_Status" varchar(20),
	"Current_Stage" varchar(50),
	"Registered_By" uuid
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "Startup_Membership" (
	"Membership_ID" serial PRIMARY KEY NOT NULL,
	"User_ID" uuid NOT NULL,
	"Startup_ID" integer NOT NULL,
	"Project_Role" varchar(50),
	"Join_Date" date
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "User" (
	"User_ID" uuid PRIMARY KEY NOT NULL,
	"Role_ID" integer NOT NULL,
	"First_Name" varchar(50) NOT NULL,
	"Last_Name" varchar(50) NOT NULL,
	"Email" varchar(100) NOT NULL,
	"Phone" varchar(20),
	"Department" varchar(100),
	"Registration_Date" date,
	"Status" varchar(20)
);
