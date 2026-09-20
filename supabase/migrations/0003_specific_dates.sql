-- Allows an activity to be a one-off on a specific calendar date instead of
-- a plain weekly recurrence. day_of_week stays populated either way (for a
-- one-off it's simply derived from specific_date), so all existing
-- weekday-based matching/display logic keeps working unchanged; specific_date
-- is the extra signal that narrows an entry to that exact date.

alter table activities add column if not exists specific_date date;

create index if not exists activities_specific_date_idx on activities (specific_date);
