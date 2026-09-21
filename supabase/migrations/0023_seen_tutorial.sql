-- Whether the user has dismissed the tutorial for good (checked "don't show
-- again"). Stored server-side, not just in local browser storage, since an
-- in-app/webview browser can wipe local storage between sessions and show
-- the tutorial again every login.
alter table profiles add column if not exists has_seen_tutorial boolean not null default false;
