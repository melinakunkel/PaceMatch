-- Blocking: hidden in both directions — the blocked person never learns
-- they were blocked, and only the blocker can list their own blocks.
create table if not exists blocks (
  blocker_id uuid not null references profiles (id) on delete cascade,
  blocked_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table blocks enable row level security;

create policy "users manage own blocks" on blocks
  for all using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);

-- Returns everyone mutually excluded from the caller's perspective (people
-- they blocked, plus people who blocked them) without revealing which
-- direction — used client-side to filter match/discover candidates.
create or replace function public.blocked_user_ids()
returns table (user_id uuid)
language sql
security definer set search_path = public
stable
as $$
  select blocked_id as user_id from blocks where blocker_id = auth.uid()
  union
  select blocker_id as user_id from blocks where blocked_id = auth.uid();
$$;

-- A blocked user can no longer be added to a new group (direct message or
-- match) by the other side, in either direction.
drop policy if exists "users can join a group or be added by its creator" on group_members;
create policy "users can join a group or be added by its creator" on group_members
  for insert with check (
    auth.uid() = user_id
    or (
      auth.uid() = (select created_by from groups where id = group_id)
      and not exists (
        select 1 from blocks
        where (blocker_id = auth.uid() and blocked_id = user_id)
           or (blocker_id = user_id and blocked_id = auth.uid())
      )
    )
  );

-- Realtime "new Sportbuddy" notifications used to piggyback on a `likes`
-- SELECT policy that let a recipient read one-directional likes — exactly
-- the leak fixed below. This table replaces it: only a completed mutual
-- match is ever written here, and only to the two people it happened to, so
-- it never reveals a one-directional "X liked you" before you reciprocate.
create table if not exists match_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  other_user_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table match_events enable row level security;
create policy "users see own match events" on match_events
  for select using (auth.uid() = user_id);
-- No insert/update/delete policies: only like_user() (security definer,
-- defined below) writes to this table.
alter publication supabase_realtime add table match_events;

-- Likes: a one-directional like used to be selectable by its recipient
-- (auth.uid() = to_user), letting someone query the REST API directly to
-- see who liked them before swiping back — defeating the blind-until-mutual
-- mechanic. Now you can only see likes you sent; matching/creating likes and
-- reading the mutual buddy list go through the functions below instead.
drop policy if exists "users see likes involving them" on likes;
create policy "users see own outgoing likes" on likes
  for select using (auth.uid() = from_user);

-- Records a like and reports whether it's now mutual — refuses to create
-- contact between blocked users, and on a mutual match writes a
-- match_events row for both sides so they're notified live.
create or replace function public.like_user(target uuid, target_activity uuid default null)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  mutual boolean;
begin
  if exists (
    select 1 from blocks
    where (blocker_id = auth.uid() and blocked_id = target)
       or (blocker_id = target and blocked_id = auth.uid())
  ) then
    raise exception 'blocked';
  end if;

  insert into likes (from_user, to_user, activity_id)
  values (auth.uid(), target, target_activity)
  on conflict (from_user, to_user) do nothing;

  select exists (
    select 1 from likes where from_user = target and to_user = auth.uid()
  ) into mutual;

  if mutual then
    insert into match_events (user_id, other_user_id) values (auth.uid(), target);
    insert into match_events (user_id, other_user_id) values (target, auth.uid());
  end if;

  return mutual;
end;
$$;

-- Mutual likes ("Sportbuddys") for the caller — computed server-side so the
-- client never needs to read who liked it that it hasn't already liked back.
create or replace function public.get_buddies()
returns table (buddy_id uuid, connected_at timestamptz, activity_id uuid)
language sql
security definer set search_path = public
stable
as $$
  select
    l1.to_user as buddy_id,
    greatest(l1.created_at, l2.created_at) as connected_at,
    l1.activity_id
  from likes l1
  join likes l2 on l2.from_user = l1.to_user and l2.to_user = l1.from_user
  where l1.from_user = auth.uid()
  order by greatest(l1.created_at, l2.created_at) desc
  limit 200;
$$;

-- Report escalation: auto-hide a profile from matching/discovery once it's
-- collected enough reports, without needing an admin dashboard yet.
alter table profiles add column if not exists report_count int not null default 0;
alter table profiles add column if not exists is_suspended boolean not null default false;

create or replace function public.handle_new_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update profiles
  set report_count = report_count + 1,
      is_suspended = (report_count + 1) >= 3
  where id = new.reported_user_id;
  return new;
end;
$$;

drop trigger if exists on_report_created on reports;
create trigger on_report_created
  after insert on reports
  for each row execute function public.handle_new_report();

-- Invite-code join attempts: throttle guessing a circle's 6-character code
-- by locking a user out for 10 minutes after 10 failed tries.
create table if not exists circle_join_attempts (
  user_id uuid primary key references profiles (id) on delete cascade,
  attempt_count int not null default 0,
  window_started_at timestamptz not null default now()
);
alter table circle_join_attempts enable row level security;
-- No client-facing policies: only join_circle_by_code (security definer)
-- touches this table.

create or replace function public.join_circle_by_code(code text)
returns circles
language plpgsql
security definer set search_path = public
as $$
declare
  found circles;
  attempts circle_join_attempts;
begin
  select * into attempts from circle_join_attempts where user_id = auth.uid();
  if attempts.user_id is null then
    insert into circle_join_attempts (user_id) values (auth.uid())
    returning * into attempts;
  elsif now() - attempts.window_started_at > interval '10 minutes' then
    update circle_join_attempts
      set attempt_count = 0, window_started_at = now()
      where user_id = auth.uid()
      returning * into attempts;
  end if;

  if attempts.attempt_count >= 10 then
    raise exception 'too many attempts, try again later';
  end if;

  select * into found from circles where invite_code = upper(code);

  if found.id is null then
    update circle_join_attempts
      set attempt_count = attempt_count + 1
      where user_id = auth.uid();
    raise exception 'invite code not found';
  end if;

  insert into circle_members (circle_id, user_id)
  values (found.id, auth.uid())
  on conflict do nothing;
  return found;
end;
$$;
