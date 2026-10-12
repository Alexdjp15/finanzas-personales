-- Daily run at 13:00 UTC = 08:00 in Bogota (UTC-5, no daylight saving).
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'process-recurring-payments',
  '0 13 * * *',
  $$select public.process_due_recurring_payments()$$
);
