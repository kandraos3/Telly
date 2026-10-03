# Database Sources Have Moved

The schema and seed files that used to live here were duplicated copies that drifted from the migrations actually applied. Per Sprint 6 decision **D5**, there is now one source of truth:

| What | Where |
| :--- | :--- |
| Executable migrations | [`supabase/migrations/`](../../supabase/migrations/) |
| Seed data (50 recognition titles) | [`supabase/seed.sql`](../../supabase/seed.sql) |
| pgTAP tests | [`supabase/tests/`](../../supabase/tests/) |
| Normative contract (tables, keys, RLS, RPCs) | [`technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md`](../technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md) |
