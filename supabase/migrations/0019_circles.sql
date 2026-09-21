-- "Kreise" (Circles): private, invite-only spaces (e.g. a friend group)
-- that can be switched into so Sportplan, Entdecken and Sportbuddys only
-- show that circle's own activities instead of the public pool.

create table circles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
  created_by uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table circle_members (
  circle_id uuid not null references circles (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

alter table activities add column circle_id uuid references circles (id) on delete set null;

create index circle_members_user_id_idx on circle_members (user_id);
create index activities_circle_id_idx on activities (circle_id);

alter table circles enable row level security;
alter table circle_members enable row level security;

create policy "circles viewable by members or creator" on circles
  for select using (
    auth.uid() = created_by
    or exists (
      select 1 from circle_members cm
      where cm.circle_id = circles.id and cm.user_id = auth.uid()
    )
  );

create policy "users can create circles" on circles
  for insert with check (auth.uid() = created_by);

create policy "creator can update circle" on circles
  for update using (auth.uid() = created_by);

create policy "creator can delete circle" on circles
  for delete using (auth.uid() = created_by);

create policy "members viewable by fellow members" on circle_members
  for select using (
    exists (
      select 1 from circle_members cm
      where cm.circle_id = circle_members.circle_id and cm.user_id = auth.uid()
    )
  );

create policy "creator can add members" on circle_members
  for insert with check (
    auth.uid() = (select created_by from circles where id = circle_id)
  );

create policy "users can leave a circle" on circle_members
  for delete using (auth.uid() = user_id);

-- Joining via invite code runs as this function (not a direct insert) so a
-- user doesn't need a SELECT policy on circles they aren't a member of yet
-- just to look their invite code up.
create function public.join_circle_by_code(code text)
returns circles
language plpgsql
security definer set search_path = public
as $$
declare
  found circles;
begin
  select * into found from circles where invite_code = upper(code);
  if found.id is null then
    raise exception 'invite code not found';
  end if;
  insert into circle_members (circle_id, user_id)
  values (found.id, auth.uid())
  on conflict do nothing;
  return found;
end;
$$;

-- Circle-scoped activities are only visible to that circle's members;
-- public (circle_id is null) activities stay visible to everyone signed in.
drop policy "activities are viewable by authenticated users" on activities;
create policy "activities are viewable by authenticated users" on activities
  for select using (
    circle_id is null
    or exists (
      select 1 from circle_members cm
      where cm.circle_id = activities.circle_id and cm.user_id = auth.uid()
    )
  );
