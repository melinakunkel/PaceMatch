-- Tennis (and future sports needing a reserved venue): whether the activity
-- creator already has a court/place or is still looking for one.
alter table activities add column if not exists venue_status text;

-- Up to 3 interests picked from a fixed client-side list, for shared-interest
-- matching context on profiles.
alter table profiles add column if not exists interests text[] not null default '{}';

-- Preferred language ('de', 'en', or 'other' for now).
alter table profiles add column if not exists language text;

-- When enabled, chats with no new messages for 7 days are archived
-- automatically (checked client-side when the chat list is opened).
alter table profiles add column if not exists auto_archive_inactive_chats boolean not null default false;
