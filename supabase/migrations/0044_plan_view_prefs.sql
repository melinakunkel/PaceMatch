-- The Sportplan's visible time range and list/week view are saved on the
-- account, not only in the browser: in-app browsers wipe local storage, so
-- the chosen range was lost on every new login.
alter table profiles add column if not exists plan_hour_start int;
alter table profiles add column if not exists plan_hour_end int;
alter table profiles add column if not exists plan_view_mode text;
