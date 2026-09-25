-- "🎉 Neuer Match für dein Laufen am Samstag": when someone adds a sport
-- time, everyone whose existing sport time now matches it (same sport, same
-- day, overlapping time — the same rules as the app's matching) gets a
-- push. So an empty match list is only a waiting room.
--
-- At most one such push per person pair per day, so someone adding
-- "Jeden Tag" doesn't send seven.

create table if not exists match_push_log (
  recipient uuid not null references profiles (id) on delete cascade,
  other_user uuid not null references profiles (id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (recipient, other_user)
);
-- No policies: only the trigger below reads/writes it.
alter table match_push_log enable row level security;

create or replace function public.push_on_new_activity()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  me profiles;
  today date := (now() at time zone 'Europe/Vienna')::date;
  r record;
begin
  if not new.is_active or coalesce(new.specific_date, today) < today then
    return new;
  end if;
  select * into me from profiles where id = new.user_id;
  if not found or me.is_suspended or me.paused_at is not null then
    return new;
  end if;

  for r in
    select distinct on (a.user_id) a.id as activity_id, a.user_id
    from activities a
    join profiles p on p.id = a.user_id
    join push_subscriptions s on s.user_id = a.user_id
    where a.sport = new.sport
      and a.day_of_week = new.day_of_week
      and a.is_active
      and a.user_id <> new.user_id
      and a.circle_id is not distinct from new.circle_id
      and a.start_time < new.end_time
      and new.start_time < a.end_time
      and (a.specific_date is null or new.specific_date is null
           or a.specific_date = new.specific_date)
      and coalesce(a.specific_date, today) >= today
      and not p.is_suspended
      and p.paused_at is null
      and not exists (
        select 1 from blocks b
        where (b.blocker_id = a.user_id and b.blocked_id = new.user_id)
           or (b.blocker_id = new.user_id and b.blocked_id = a.user_id)
      )
      -- The recipient's own preferences, as the app applies them when
      -- they open their matches.
      and not (
        me.gender is not null and p.gender is not null and me.gender <> p.gender
        and (me.gender_preference = 'same_only' or p.gender_preference = 'same_only')
      )
      and (me.age is null or p.age_range_min is null or me.age >= p.age_range_min)
      and (me.age is null or p.age_range_max is null or me.age <= p.age_range_max)
      -- Already liked each other: nothing new to tell.
      and not exists (
        select 1 from likes l
        where l.from_user = a.user_id and l.to_user = new.user_id
      )
      and not exists (
        select 1 from match_push_log m
        where m.recipient = a.user_id and m.other_user = new.user_id
          and m.sent_at > now() - interval '24 hours'
      )
    order by a.user_id, a.created_at desc
  loop
    insert into match_push_log (recipient, other_user)
    values (r.user_id, new.user_id)
    on conflict (recipient, other_user) do update set sent_at = now();
    perform send_push_event(jsonb_build_object(
      'type', 'new_match',
      'user_id', r.user_id,
      'activity_id', r.activity_id,
      'other_activity_id', new.id
    ));
  end loop;
  return new;
exception when others then
  -- Never block saving a sport time because of a notification.
  return new;
end;
$$;

drop trigger if exists push_on_new_activity on activities;
create trigger push_on_new_activity
  after insert on activities
  for each row execute function public.push_on_new_activity();
