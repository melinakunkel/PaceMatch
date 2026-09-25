-- Feedback round 2:
-- * Matching respects distance (new-match push too): each person's radius
--   around their place must reach the other's.
-- * Mute push per chat, and "Ruhezeit" (quiet hours) per person — both
--   read by the Edge Function "push".
-- * Team sports: how many players someone is looking for.

alter table group_members add column if not exists muted boolean not null default false;

alter table profiles add column if not exists push_quiet_start time;
alter table profiles add column if not exists push_quiet_end time;

alter table activities add column if not exists players_wanted int not null default 1;
alter table activities drop constraint if exists activities_players_wanted_check;
alter table activities add constraint activities_players_wanted_check
  check (players_wanted between 1 and 10);

-- Great-circle distance in km.
create or replace function public.distance_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371 * 2 * asin(least(1, sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
      * power(sin(radians(lon2 - lon1) / 2), 2)
  )));
$$;

-- Muted members don't count as "someone to push to".
create or replace function public.push_on_message()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (
    select 1
    from group_members gm
    join push_subscriptions ps on ps.user_id = gm.user_id
    where gm.group_id = new.group_id
      and gm.user_id <> new.sender_id
      and not gm.muted
  ) then
    perform send_push_event(jsonb_build_object('type', 'message', 'id', new.id));
  end if;
  return new;
end;
$$;

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
      -- Close enough to meet (same rule as the app): no place on either
      -- side counts as flexible; (0, 0) is a name-only place.
      and (
        a.latitude is null or a.longitude is null
        or new.latitude is null or new.longitude is null
        or (a.latitude = 0 and a.longitude = 0)
        or (new.latitude = 0 and new.longitude = 0)
        or distance_km(a.latitude, a.longitude, new.latitude, new.longitude)
           <= a.radius_km + new.radius_km
      )
      and not p.is_suspended
      and p.paused_at is null
      and not exists (
        select 1 from blocks b
        where (b.blocker_id = a.user_id and b.blocked_id = new.user_id)
           or (b.blocker_id = new.user_id and b.blocked_id = a.user_id)
      )
      -- The recipient's own preferences, as the app applies them when
      -- they open their matches.
      -- coalesce: with no preference set the comparison is NULL, which
      -- must count as "allowed", not silently drop the person.
      and not coalesce(
        me.gender <> p.gender
        and (me.gender_preference = 'same_only' or p.gender_preference = 'same_only'),
        false
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
  raise warning 'push_on_new_activity failed: %', sqlerrm;
  return new;
end;
$$;

