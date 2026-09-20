-- Coordinates for a group's meeting point, so chat members can see it on a
-- map instead of just reading a text label.
alter table groups add column if not exists latitude double precision;
alter table groups add column if not exists longitude double precision;
