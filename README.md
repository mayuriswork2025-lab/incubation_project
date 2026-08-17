Startup Incubator Management System — Database Project

A relational database for managing startups, mentors, funding requests, milestones, and demo day evaluations within a startup incubator program.

Overview
11 entities: Role, User, Startup, Startup Membership, Mentor Request, Mentor Assignment, Meeting, Milestone, Funding Request, Demo Day, Evaluation
Database: PostgreSQL, hosted on Supabase (free tier)
ER Diagram: see docs/ER_diagram.png
Project Structure
├── schema/
│   └── startup_incubator_schema.sql   # Full DDL: tables, keys, indexes, sample data
├── queries/
│   └── sample_queries.sql             # Useful SELECT/JOIN queries for reports
├── docs/
│   ├── ER_diagram.png                 # Entity-relationship diagram
│   └── requirements.md                # Business rules / requirements
└── README.md
