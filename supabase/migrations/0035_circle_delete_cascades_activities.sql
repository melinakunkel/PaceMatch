-- Deleting a circle now also deletes the activities that were scoped to
-- it, instead of leaving them behind as newly-public activities (the
-- previous "on delete set null" behavior from 0019) — that turned out to
-- be the wrong default once circle deletion actually shipped in 0033/0034.

alter table activities drop constraint activities_circle_id_fkey;
alter table activities add constraint activities_circle_id_fkey
  foreign key (circle_id) references circles (id) on delete cascade;
