-- Remove demo data except admin
-- Run in Supabase SQL editor after confirming admin login works
delete from public.missing_day_dismissals;
delete from public.notifications;
delete from public.time_entries;
delete from public.engagements;
delete from public.applications;
delete from public.jobs;
delete from public.sessions;
delete from public.assistants;
delete from public.clients;
update public.admins set last_login_at = null where lower(username) = 'admin';
update public.settings set value = '18.66' where key = 'fx_rate';
delete from public.audit_log;
-- keep admins and settings
