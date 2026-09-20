-- Per-activity skill level (for sports without a numeric pace) and bike
-- sub-type (for cycling).
alter table activities add column if not exists level text;
alter table activities add column if not exists bike_type text;

-- New sport: pregnancy / postpartum fitness.
alter type sport_type add value if not exists 'schwangerschaftssport';
