DROP TABLE IF EXISTS Evaluation CASCADE;
DROP TABLE IF EXISTS evaluation CASCADE;
DROP TABLE IF EXISTS Demo_Day_Participant CASCADE;
DROP TABLE IF EXISTS Demo_Day CASCADE;
DROP TABLE IF EXISTS demo_day CASCADE;
DROP TABLE IF EXISTS Funding_Request CASCADE;
DROP TABLE IF EXISTS funding_request CASCADE;
DROP TABLE IF EXISTS Milestone CASCADE;
DROP TABLE IF EXISTS milestone CASCADE;
DROP TABLE IF EXISTS Meeting CASCADE;
DROP TABLE IF EXISTS meeting CASCADE;
DROP TABLE IF EXISTS Mentor_Assignment CASCADE;
DROP TABLE IF EXISTS mentor_assignment CASCADE;
DROP TABLE IF EXISTS Mentor_Request CASCADE;
DROP TABLE IF EXISTS mentor_request CASCADE;
DROP TABLE IF EXISTS Startup_Membership CASCADE;
DROP TABLE IF EXISTS startup_membership CASCADE;
DROP TABLE IF EXISTS Startup CASCADE;
DROP TABLE IF EXISTS startup CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;
DROP TABLE IF EXISTS Role CASCADE;
DROP TABLE IF EXISTS role CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE TABLE Role (
    Role_ID     SERIAL PRIMARY KEY,
    Role_Name   VARCHAR(50) NOT NULL,
    Description TEXT
);

CREATE TABLE "User" (
    User_ID            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    Role_ID            INT NOT NULL REFERENCES Role(Role_ID),
    First_Name         VARCHAR(50) NOT NULL,
    Last_Name          VARCHAR(50) NOT NULL,
    Email              VARCHAR(100) UNIQUE NOT NULL,
    Phone              VARCHAR(20) UNIQUE,
    Department         VARCHAR(100),
    Registration_Date  DATE DEFAULT CURRENT_DATE,
    Status             VARCHAR(20) DEFAULT 'Active'
        CHECK (Status IN ('Active', 'Inactive', 'Suspended'))
);

CREATE TABLE Startup (
    Startup_ID           SERIAL PRIMARY KEY,
    Startup_Name         VARCHAR(100) NOT NULL,
    Domain                VARCHAR(100),
    Description           TEXT,
    Registration_Date     DATE DEFAULT CURRENT_DATE,
    Registration_Status   VARCHAR(20) DEFAULT 'Pending'
        CHECK (Registration_Status IN ('Pending', 'Approved', 'Rejected')),
    Current_Stage         VARCHAR(50),
    Registered_By         UUID REFERENCES "User"(User_ID)
);

CREATE TABLE Startup_Membership (
    Membership_ID SERIAL PRIMARY KEY,
    User_ID       UUID NOT NULL REFERENCES "User"(User_ID),
    Startup_ID    INT NOT NULL REFERENCES Startup(Startup_ID),
    Project_Role  VARCHAR(50),
    Join_Date     DATE DEFAULT CURRENT_DATE,
    UNIQUE (User_ID, Startup_ID)
);

CREATE TABLE Milestone (
    Milestone_ID          SERIAL PRIMARY KEY,
    Startup_ID            INT NOT NULL REFERENCES Startup(Startup_ID),
    Milestone_Name        VARCHAR(100) NOT NULL,
    Due_Date              DATE,
    Completion_Date       DATE,
    Status                VARCHAR(20) DEFAULT 'Pending'
        CHECK (Status IN ('Pending', 'In_Progress', 'Completed')),
    Verification_Status   VARCHAR(20)
        CHECK (Verification_Status IN ('Unverified', 'Verified', 'Rejected')),
    Mentor_Remarks        TEXT
);
ALTER TABLE Role ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE Startup ENABLE ROW LEVEL SECURITY;
ALTER TABLE Startup_Membership ENABLE ROW LEVEL SECURITY;
ALTER TABLE Milestone ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM "User" u
    JOIN Role r ON r.Role_ID = u.Role_ID
    WHERE u.User_ID = auth.uid() AND r.Role_Name = 'Admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE POLICY "Read all profiles" ON "User" FOR SELECT USING (true);
CREATE POLICY "Edit own profile" ON "User" FOR UPDATE USING (auth.uid() = User_ID OR is_admin());

CREATE POLICY "Founder access to own startup" ON Startup
    FOR ALL USING (
        is_admin()
        OR EXISTS (SELECT 1 FROM Startup_Membership sm WHERE sm.Startup_ID = Startup.Startup_ID AND sm.User_ID = auth.uid())
    );

CREATE POLICY "Membership visible to startup members" ON Startup_Membership
    FOR ALL USING (
        is_admin()
        OR User_ID = auth.uid()
        OR EXISTS (SELECT 1 FROM Startup_Membership sm2 WHERE sm2.Startup_ID = Startup_Membership.Startup_ID AND sm2.User_ID = auth.uid())
    );

CREATE POLICY "Milestone access" ON Milestone
    FOR ALL USING (
        is_admin()
        OR EXISTS (SELECT 1 FROM Startup_Membership sm WHERE sm.Startup_ID = Milestone.Startup_ID AND sm.User_ID = auth.uid())
    );

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public."User" (user_id, role_id, first_name, last_name, email)
  VALUES (
    new.id,
    COALESCE((new.raw_user_meta_data->>'role_id')::int, 3),
    COALESCE(new.raw_user_meta_data->>'first_name', 'New'),
    COALESCE(new.raw_user_meta_data->>'last_name', 'User'),
    new.email
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
INSERT INTO Role (Role_Name, Description) VALUES
('Admin', 'Full platform access'),
('Mentor', 'Advises assigned startups'),
('Founder', 'Registers and runs a startup'),
('Judge', 'Scores startups at demo days');
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
SELECT * FROM Role;
SELECT tgname FROM pg_trigger WHERE tgname='on_auth_user_created';
SELECT * FROM "User";
SELECT user_id FROM "User" WHERE email='founder2@test.com';
INSERT INTO Startup (Startup_Name, Domain, Description, Registered_By) VALUES ('EcoTrack','CleanTech','Carbon footprint tracker','239a1e8b-3c3f-40fb-ac59-303478e9bd9e') RETURNING startup_id;
INSERT INTO Startup_Membership (User_ID, Startup_ID, Project_Role) VALUES ('239a1e8b-3c3f-40fb-ac59-303478e9bd9e',1,'Founder');
INSERT INTO Milestone (Startup_ID, Milestone_Name, Due_Date, Status) VALUES (1,'MVP Launch','2026-09-30','Pending');
SELECT u.first_name, s.startup_name, sm.project_role, m.milestone_name, m.status 
FROM "User" u JOIN Startup_Membership sm ON sm.user_id = u.user_id JOIN Startup s ON s.startup_id = sm.startup_id
JOIN Milestone m ON m.startup_id = s.startup_id WHERE u.user_id = '239a1e8b-3c3f-40fb-ac59-303478e9bd9e';
