-- Initial schema for the Startup Incubator Management System.
-- Restructured from schema/startup_incubator_schema.sql: DDL, RLS policies, and the
-- auth trigger live here; ad-hoc sample data/queries were moved out to supabase/seed.sql.

drop table if exists "Milestone" cascade;
drop table if exists "Startup_Membership" cascade;
drop table if exists "Startup" cascade;
drop table if exists "User" cascade;
drop table if exists "Role" cascade;
drop function if exists public.handle_new_user() cascade;

create table "Role" (
    Role_ID     serial primary key,
    Role_Name   varchar(50) not null,
    Description text
);

create table "User" (
    User_ID            uuid primary key references auth.users(id) on delete cascade,
    Role_ID            int not null references "Role"(Role_ID),
    First_Name         varchar(50) not null,
    Last_Name          varchar(50) not null,
    Email              varchar(100) unique not null,
    Phone              varchar(20) unique,
    Department         varchar(100),
    Registration_Date  date default current_date,
    Status             varchar(20) default 'Active'
        check (Status in ('Active', 'Inactive', 'Suspended'))
);

create table "Startup" (
    Startup_ID           serial primary key,
    Startup_Name         varchar(100) not null,
    Domain                varchar(100),
    Description           text,
    Registration_Date     date default current_date,
    Registration_Status   varchar(20) default 'Pending'
        check (Registration_Status in ('Pending', 'Approved', 'Rejected')),
    Current_Stage         varchar(50),
    Registered_By         uuid references "User"(User_ID)
);

create table "Startup_Membership" (
    Membership_ID serial primary key,
    User_ID       uuid not null references "User"(User_ID),
    Startup_ID    int not null references "Startup"(Startup_ID),
    Project_Role  varchar(50),
    Join_Date     date default current_date,
    unique (User_ID, Startup_ID)
);

create table "Milestone" (
    Milestone_ID          serial primary key,
    Startup_ID            int not null references "Startup"(Startup_ID),
    Milestone_Name        varchar(100) not null,
    Due_Date              date,
    Completion_Date       date,
    Status                varchar(20) default 'Pending'
        check (Status in ('Pending', 'In_Progress', 'Completed')),
    Verification_Status   varchar(20)
        check (Verification_Status in ('Unverified', 'Verified', 'Rejected')),
    Mentor_Remarks        text
);

alter table "Role" enable row level security;
alter table "User" enable row level security;
alter table "Startup" enable row level security;
alter table "Startup_Membership" enable row level security;
alter table "Milestone" enable row level security;

create or replace function is_admin() returns boolean as $$
  select exists (
    select 1 from "User" u
    join "Role" r on r.Role_ID = u.Role_ID
    where u.User_ID = auth.uid() and r.Role_Name = 'Admin'
  );
$$ language sql security definer stable;

create policy "Read all profiles" on "User" for select using (true);
create policy "Edit own profile" on "User" for update using (auth.uid() = User_ID or is_admin());

create policy "Founder access to own startup" on "Startup"
    for all using (
        is_admin()
        or exists (select 1 from "Startup_Membership" sm where sm.Startup_ID = "Startup".Startup_ID and sm.User_ID = auth.uid())
    );

create policy "Membership visible to startup members" on "Startup_Membership"
    for all using (
        is_admin()
        or User_ID = auth.uid()
        or exists (select 1 from "Startup_Membership" sm2 where sm2.Startup_ID = "Startup_Membership".Startup_ID and sm2.User_ID = auth.uid())
    );

create policy "Milestone access" on "Milestone"
    for all using (
        is_admin()
        or exists (select 1 from "Startup_Membership" sm where sm.Startup_ID = "Milestone".Startup_ID and sm.User_ID = auth.uid())
    );

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public."User" (user_id, role_id, first_name, last_name, email)
  values (
    new.id,
    coalesce((new.raw_user_meta_data->>'role_id')::int, 3),
    coalesce(new.raw_user_meta_data->>'first_name', 'New'),
    coalesce(new.raw_user_meta_data->>'last_name', 'User'),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

insert into "Role" (Role_Name, Description) values
('Admin', 'Full platform access'),
('Mentor', 'Advises assigned startups'),
('Founder', 'Registers and runs a startup'),
('Judge', 'Scores startups at demo days');
