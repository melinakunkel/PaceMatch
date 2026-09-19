-- SAMEPACE initial schema
-- Sport types shown in the app's onboarding grid.
create type sport_type as enum ('laufen', 'radfahren', 'schwimmen', 'wandern', 'tennis', 'sonstige');

-- One row per user, created automatically on signup (see trigger below).
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  age int,
  city text,
  avatar_url text,
  bio text,
  reliability_score numeric not null default 100 check (reliability_score between 0 and 100),
  created_at timestamptz not null default now()
);

-- Sports a user practices, with their level / pace range, shown on the profile screen.
create table user_sports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  sport sport_type not null,
  level text,
  -- unit is 'min_per_km' (running/swimming/walking) or 'km_per_h' (cycling/tennis n/a)
  unit text not null default 'min_per_km',
  value_low numeric,
  value_high numeric,
  unique (user_id, sport)
);

-- A recurring or one-off slot in a user's weekly Sportplan.
create table activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  sport sport_type not null,
  day_of_week int not null check (day_of_week between 1 and 7), -- 1 = Montag ... 7 = Sonntag
  start_time time not null,
  end_time time not null,
  location_name text,
  latitude double precision,
  longitude double precision,
  radius_km numeric not null default 3,
  distance_min_km numeric,
  distance_max_km numeric,
  pace_min numeric,
  pace_max numeric,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- A meetup formed out of matching activities ("Gruppe erstellen").
create table groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sport sport_type not null,
  created_by uuid not null references profiles (id) on delete cascade,
  meeting_point text,
  meeting_latitude double precision,
  meeting_longitude double precision,
  meeting_time timestamptz,
  activity_id uuid references activities (id) on delete set null,
  created_at timestamptz not null default now()
);

create table group_members (
  group_id uuid not null references groups (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  attended boolean,
  primary key (group_id, user_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups (id) on delete cascade,
  sender_id uuid not null references profiles (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index activities_user_id_idx on activities (user_id);
create index activities_sport_day_idx on activities (sport, day_of_week);
create index group_members_user_id_idx on group_members (user_id);
create index messages_group_id_idx on messages (group_id, created_at);

-- Auto-create a profile row whenever a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'Neue:r Nutzer:in'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Row Level Security -------------------------------------------------------

alter table profiles enable row level security;
alter table user_sports enable row level security;
alter table activities enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;
alter table messages enable row level security;

-- profiles: everyone signed in can browse profiles (needed for matching), only owner can edit.
create policy "profiles are viewable by authenticated users" on profiles
  for select using (auth.role() = 'authenticated');
create policy "users can update own profile" on profiles
  for update using (auth.uid() = id);

-- user_sports: viewable by anyone signed in (matching), editable by owner.
create policy "user_sports are viewable by authenticated users" on user_sports
  for select using (auth.role() = 'authenticated');
create policy "users manage own sports" on user_sports
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- activities: viewable by anyone signed in (matching), editable by owner.
create policy "activities are viewable by authenticated users" on activities
  for select using (auth.role() = 'authenticated');
create policy "users manage own activities" on activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- groups: viewable by members or the creator; creatable by any signed in user; editable by creator.
create policy "groups viewable by members" on groups
  for select using (
    auth.uid() = created_by
    or exists (
      select 1 from group_members gm
      where gm.group_id = groups.id and gm.user_id = auth.uid()
    )
  );
create policy "users can create groups" on groups
  for insert with check (auth.uid() = created_by);
create policy "creator can update group" on groups
  for update using (auth.uid() = created_by);

-- group_members: members can see fellow members; users can join/leave themselves.
create policy "members viewable by group members" on group_members
  for select using (
    exists (
      select 1 from group_members gm
      where gm.group_id = group_members.group_id and gm.user_id = auth.uid()
    )
  );
create policy "users can join a group or be added by its creator" on group_members
  for insert with check (
    auth.uid() = user_id
    or auth.uid() = (select created_by from groups where id = group_id)
  );
create policy "users can leave a group" on group_members
  for delete using (auth.uid() = user_id);

-- messages: only group members can read/write.
create policy "messages viewable by group members" on messages
  for select using (
    exists (
      select 1 from group_members gm
      where gm.group_id = messages.group_id and gm.user_id = auth.uid()
    )
  );
create policy "group members can send messages" on messages
  for insert with check (
    auth.uid() = sender_id
    and exists (
      select 1 from group_members gm
      where gm.group_id = messages.group_id and gm.user_id = auth.uid()
    )
  );
