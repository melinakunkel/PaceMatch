-- One-time cleanup: identical sport times saved twice (same person,
-- sport, day/date, times, Kreis). The oldest stays; likes and chats that
-- pointed at a copy are moved over to it first. The app no longer creates
-- such copies.

update likes l
set activity_id = k.keep_id
from (
  select id, first_value(id) over (
    partition by user_id, sport, day_of_week, start_time, end_time, specific_date, circle_id
    order by created_at, id
  ) as keep_id
  from activities
) k
where l.activity_id = k.id and k.id <> k.keep_id;

update groups g
set activity_id = k.keep_id
from (
  select id, first_value(id) over (
    partition by user_id, sport, day_of_week, start_time, end_time, specific_date, circle_id
    order by created_at, id
  ) as keep_id
  from activities
) k
where g.activity_id = k.id and k.id <> k.keep_id;

delete from activities a
using (
  select id, first_value(id) over (
    partition by user_id, sport, day_of_week, start_time, end_time, specific_date, circle_id
    order by created_at, id
  ) as keep_id
  from activities
) k
where a.id = k.id and k.id <> k.keep_id;
