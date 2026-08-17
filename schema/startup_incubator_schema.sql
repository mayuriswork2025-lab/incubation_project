
-- Drop tables if re-running (children first, to respect FK order)
DROP TABLE IF EXISTS Evaluation CASCADE;
DROP TABLE IF EXISTS Demo_Day CASCADE;
DROP TABLE IF EXISTS Funding_Request CASCADE;
DROP TABLE IF EXISTS Milestone CASCADE;
DROP TABLE IF EXISTS Meeting CASCADE;
DROP TABLE IF EXISTS Mentor_Assignment CASCADE;
DROP TABLE IF EXISTS Mentor_Request CASCADE;
DROP TABLE IF EXISTS Startup_Membership CASCADE;
DROP TABLE IF EXISTS Startup CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;
DROP TABLE IF EXISTS Role CASCADE;
 
CREATE TABLE Role (
    Role_ID     SERIAL PRIMARY KEY,
    Role_Name   VARCHAR(50) NOT NULL,      -- e.g. Admin, Mentor, Startup Founder, Judge
    Description TEXT
);
 
CREATE TABLE "User" (
    User_ID            SERIAL PRIMARY KEY,
    Role_ID            INT NOT NULL REFERENCES Role(Role_ID),
    First_Name         VARCHAR(50) NOT NULL,
    Last_Name          VARCHAR(50) NOT NULL,
    Email              VARCHAR(100) UNIQUE NOT NULL,
    Phone              VARCHAR(20),
    Password           VARCHAR(255) NOT NULL,
    Department         VARCHAR(100),
    Registration_Date  DATE DEFAULT CURRENT_DATE,
    Status             VARCHAR(20) DEFAULT 'Active'
);
 
CREATE TABLE Startup (
    Startup_ID          SERIAL PRIMARY KEY,
    Startup_Name        VARCHAR(100) NOT NULL,
    Domain               VARCHAR(100),
    Description          TEXT,
    Registration_Date    DATE DEFAULT CURRENT_DATE,
    Registration_Status  VARCHAR(20) DEFAULT 'Pending',   -- Pending/Approved/Rejected
    Current_Stage        VARCHAR(50),
    Registered_By        INT REFERENCES "User"(User_ID)   -- who registered the startup
);
 
CREATE TABLE Startup_Membership (
    Membership_ID SERIAL PRIMARY KEY,
    User_ID       INT NOT NULL REFERENCES "User"(User_ID),
    Startup_ID    INT NOT NULL REFERENCES Startup(Startup_ID),
    Project_Role  VARCHAR(50),        -- e.g. Founder, Co-Founder, Team Member
    Join_Date     DATE DEFAULT CURRENT_DATE
);
 

CREATE TABLE Mentor_Request (
    MentorReq_ID         SERIAL PRIMARY KEY,
    Startup_ID           INT NOT NULL REFERENCES Startup(Startup_ID),
    Requested_By         INT NOT NULL REFERENCES "User"(User_ID),
    Required_Skills      VARCHAR(255),
    Request_Description  TEXT,
    Request_Date         DATE DEFAULT CURRENT_DATE,
    Status               VARCHAR(20) DEFAULT 'Pending',  -- Pending/Approved/Rejected
    Decided_By           INT REFERENCES "User"(User_ID),
    Decision_Date        DATE,
    Remarks              TEXT
);
 

CREATE TABLE Mentor_Assignment (
    Assignment_ID  SERIAL PRIMARY KEY,
    MentorReq_ID   INT NOT NULL REFERENCES Mentor_Request(MentorReq_ID),
    Mentor_ID      INT NOT NULL REFERENCES "User"(User_ID),
    Assigned_Date  DATE DEFAULT CURRENT_DATE,
    End_Date       DATE,
    Status         VARCHAR(20) DEFAULT 'Active'
);

CREATE TABLE Meeting (
    Meeting_ID      SERIAL PRIMARY KEY,
    Assignment_ID   INT NOT NULL REFERENCES Mentor_Assignment(Assignment_ID),
    Meeting_Date    DATE,
    Meeting_Time    TIME,
    Agenda          TEXT,
    Discussion      TEXT,
    Action_Items    TEXT,
    Meeting_Status  VARCHAR(20) DEFAULT 'Scheduled'
);
 

CREATE TABLE Milestone (
    Milestone_ID          SERIAL PRIMARY KEY,
    Startup_ID            INT NOT NULL REFERENCES Startup(Startup_ID),
    Milestone_Name        VARCHAR(100) NOT NULL,
    Due_Date              DATE,
    Completion_Date       DATE,
    Status                VARCHAR(20) DEFAULT 'Pending',
    Verification_Status   VARCHAR(20),
    Mentor_Remarks        TEXT
);
 

CREATE TABLE Funding_Request (
    Funding_ID         SERIAL PRIMARY KEY,
    Startup_ID         INT NOT NULL REFERENCES Startup(Startup_ID),
    Request_Date       DATE DEFAULT CURRENT_DATE,
    Requested_Amount   NUMERIC(12,2) NOT NULL,
    Purpose            TEXT,
    Status             VARCHAR(20) DEFAULT 'Pending',  -- Pending/Approved/Rejected
    Approved_Amount    NUMERIC(12,2),
    Decided_By         INT REFERENCES "User"(User_ID),
    Decision_Date      DATE,
    Remarks            TEXT
);
 

CREATE TABLE Demo_Day (
    DemoDay_ID  SERIAL PRIMARY KEY,
    Event_Name  VARCHAR(100) NOT NULL,
    Event_Date  DATE,
    Venue       VARCHAR(100)
);
 
CREATE TABLE Evaluation (
    Evaluation_ID        SERIAL PRIMARY KEY,
    DemoDay_ID           INT NOT NULL REFERENCES Demo_Day(DemoDay_ID),
    Startup_ID           INT NOT NULL REFERENCES Startup(Startup_ID),
    Judge_ID             INT NOT NULL REFERENCES "User"(User_ID),
    Innovation_Score     NUMERIC(4,2),
    Technical_Score      NUMERIC(4,2),
    Business_Score       NUMERIC(4,2),
    Presentation_Score   NUMERIC(4,2),
    Overall_Remarks      TEXT
);
