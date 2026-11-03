-- Removes ONLY demo data created by demo_seed.sql.
-- Demo stores have code 'DEMO-%'; demo accounts are demo.*@zonein.app.
-- Real accounts (Farrel, Gilang, Maria, tester@zonein.app) and their data are not touched.
-- Deleting a demo store also removes its visits, shelf checks, prices, sales and assignments.
delete from public.stores where code like 'DEMO-%';
delete from public.leave_requests where employee_id in (select id from auth.users where email like 'demo.%@zonein.app');
delete from auth.users where email like 'demo.%@zonein.app';  -- cascades profiles, attendance, AI insights
