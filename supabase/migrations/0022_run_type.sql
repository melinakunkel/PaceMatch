-- Optional run type ('normal', 'long_run', 'speed_run') for Laufen
-- activities, shown next to pace/distance so others can see at a glance
-- what kind of run it is.
alter table activities add column if not exists run_type text;
