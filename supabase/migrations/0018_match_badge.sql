-- Marks a group as having been created from a mutual "It's a Match" (as
-- opposed to a regular contact or an open event), so the Matches tab can
-- show a badge for ones the user hasn't seen yet.
alter table groups add column if not exists is_match boolean not null default false;
alter table profiles add column if not exists matches_seen_at timestamptz;
