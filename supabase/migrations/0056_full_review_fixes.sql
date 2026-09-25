-- Fixes from the full code review (each reproduced or checked first):
--
-- 1. An open event's host could point the event at someone else's chat
--    (e.g. a private one) and then join it through the event — reading
--    all its messages. An event's chat must be a group chat the host
--    created.
-- 2. A membership row can't be moved to another chat or person (the
--    creator of a private chat could otherwise swap in a third person).
-- 3. Automatic suspension after 3 reports now needs 3 *different*
--    people — before, one person reporting three times was enough.
-- 4. A sport time can only be put into a Kreis you're a member of.
-- 5. Profile photos: images only, at most 5 MB.

-- 1.
drop policy if exists "users can host open events" on open_events;
create policy "users can host open events" on open_events
  for insert with check (
    auth.uid() = host_id
    and exists (
      select 1 from groups g
      where g.id = group_id and g.created_by = auth.uid() and not g.is_direct
    )
  );

drop policy if exists "host can update own open event" on open_events;
create policy "host can update own open event" on open_events
  for update using (auth.uid() = host_id)
  with check (
    auth.uid() = host_id
    and exists (
      select 1 from groups g
      where g.id = group_id and g.created_by = auth.uid() and not g.is_direct
    )
  );

-- 2.
create or replace function public.protect_group_membership()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.group_id is distinct from old.group_id
          or new.user_id is distinct from old.user_id) then
    raise exception 'a membership cannot be moved';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_group_membership on group_members;
create trigger protect_group_membership
  before update on group_members
  for each row execute function public.protect_group_membership();

-- 3.
create or replace function public.handle_new_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update profiles
  set report_count = report_count + 1,
      is_suspended = is_suspended or (
        select count(distinct reporter_id) from reports
        where reported_user_id = new.reported_user_id
      ) >= 3
  where id = new.reported_user_id;
  return new;
end;
$$;

-- 4.
drop policy if exists "users manage own activities" on activities;
create policy "users manage own activities" on activities
  for all using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (circle_id is null or is_circle_member(circle_id, auth.uid()))
  );

-- 5.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic']
where id = 'avatars';
