-- User-hosted, publicly joinable events ("Offene Gruppen-Events") — unlike
-- a 1:1 match, anyone can join up to max_participants. Each event has its
-- own group chat (reusing the existing groups/group_members/messages
-- infra), so joining an event is just becoming a group member.
create table if not exists open_events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles (id) on delete cascade,
  group_id uuid not null references groups (id) on delete cascade,
  name text not null,
  sport sport_type not null,
  description text,
  event_date date not null,
  start_time time not null,
  end_time time,
  location_name text not null,
  latitude double precision,
  longitude double precision,
  city text,
  max_participants int,
  created_at timestamptz not null default now()
);

create index if not exists open_events_date_idx on open_events (event_date);
create index if not exists open_events_city_idx on open_events (city);

alter table open_events enable row level security;

drop policy if exists "open events viewable by authenticated users" on open_events;
create policy "open events viewable by authenticated users" on open_events
  for select using (auth.role() = 'authenticated');

drop policy if exists "users can host open events" on open_events;
create policy "users can host open events" on open_events
  for insert with check (auth.uid() = host_id);

drop policy if exists "host can update own open event" on open_events;
create policy "host can update own open event" on open_events
  for update using (auth.uid() = host_id);

drop policy if exists "host can delete own open event" on open_events;
create policy "host can delete own open event" on open_events
  for delete using (auth.uid() = host_id);
