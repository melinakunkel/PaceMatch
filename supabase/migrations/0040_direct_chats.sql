-- Private 1:1 chats: exactly one chat per pair of people, no matter where
-- it was started from (Entdecken, profile, chat request, match, Sportbuddys).
-- Group chats are only events and deliberately created group chats.

alter table groups add column if not exists is_direct boolean not null default false;

-- Existing chats with exactly two people that aren't an event become
-- private chats.
update groups g set is_direct = true
where not exists (select 1 from open_events e where e.group_id = g.id)
  and (select count(*) from group_members m where m.group_id = g.id) = 2;

-- If the same two people ended up with several private chats, merge them
-- into the newest one: messages move over, the older chats are removed.
-- (No temporary table: the Supabase SQL editor may run each statement on
-- its own connection.)
update messages m set group_id = d.keep_id
from (
  select group_id as old_id, keep_id
  from (
    select g.id as group_id,
           first_value(g.id) over (
             partition by a.user_id, b.user_id order by g.created_at desc, g.id
           ) as keep_id
    from groups g
    join group_members a on a.group_id = g.id
    join group_members b on b.group_id = g.id and a.user_id < b.user_id
    where g.is_direct
  ) ranked
  where group_id <> keep_id
) d
where m.group_id = d.old_id;

delete from groups where id in (
  select group_id
  from (
    select g.id as group_id,
           first_value(g.id) over (
             partition by a.user_id, b.user_id order by g.created_at desc, g.id
           ) as keep_id
    from groups g
    join group_members a on a.group_id = g.id
    join group_members b on b.group_id = g.id and a.user_id < b.user_id
    where g.is_direct
  ) ranked
  where group_id <> keep_id
);

-- Both people in a private chat may change its meeting details (sport,
-- meeting point, time) — it's reused for every meetup of the two.
drop policy if exists "direct chat members can update group" on groups;
create policy "direct chat members can update group" on groups
  for update using (is_direct and is_group_member(id, auth.uid()))
  with check (is_direct);

-- A private chat is reused for several meetups, so "did it happen?" is
-- remembered per meeting time rather than once per chat.
alter table group_members add column if not exists checked_in_for timestamptz;

update group_members m set checked_in_for = g.meeting_time
from groups g
where g.id = m.group_id and m.attended is not null and m.checked_in_for is null;

-- Same for reviews: one per person per meetup, not per chat.
alter table meetup_reviews add column if not exists meeting_time timestamptz;

update meetup_reviews r set meeting_time = coalesce(g.meeting_time, r.created_at)
from groups g
where g.id = r.group_id and r.meeting_time is null;

update meetup_reviews set meeting_time = created_at where meeting_time is null;

alter table meetup_reviews alter column meeting_time set not null;
alter table meetup_reviews drop constraint if exists meetup_reviews_pkey;
alter table meetup_reviews add primary key (group_id, reviewer_id, reviewee_id, meeting_time);
