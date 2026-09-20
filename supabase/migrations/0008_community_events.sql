-- Curated, publicly-known running-club events (not tied to a user),
-- shown in the Entdecken screen with a star badge as "an event exists
-- nearby" rather than a real match. This is a hand-maintained list, not
-- a live scraper — add more rows the same way to extend it.

create table if not exists community_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source text,
  sport sport_type not null default 'laufen',
  day_of_week int check (day_of_week between 1 and 7), -- 1=Mo..7=So, null if one-off
  specific_date date, -- set instead of day_of_week for a one-off event
  start_time time not null,
  end_time time,
  location_name text not null,
  latitude double precision,
  longitude double precision,
  city text not null,
  url text,
  created_at timestamptz not null default now()
);

alter table community_events enable row level security;

drop policy if exists "community events are viewable by authenticated users" on community_events;
create policy "community events are viewable by authenticated users" on community_events
  for select using (auth.role() = 'authenticated');

-- Seed: real, publicly known recurring Vienna run clubs (Sept 2026).
insert into community_events (name, source, sport, day_of_week, start_time, end_time, location_name, latitude, longitude, city, url) values
  ('Donaupark parkrun', 'parkrun Austria', 'laufen', 6, '09:00', '09:45',
   'Donaupark, Arbeiterstrandbadstraße 122, 1220 Wien', 48.2436, 16.4302, 'Wien',
   'https://www.parkrun.co.at/donaupark/'),
  ('Classic Run', 'adidas Runners Vienna', 'laufen', 1, '18:30', '19:30',
   'Runbase, Badeschiff, Schwedenplatz, Wien', 48.2131, 16.3789, 'Wien',
   'https://adidasrunners.adidas.com/community/vienna'),
  ('Speed Session', 'adidas Runners Vienna', 'laufen', 4, '18:30', '19:30',
   'Runbase, Badeschiff, Schwedenplatz, Wien', 48.2131, 16.3789, 'Wien',
   'https://adidasrunners.adidas.com/community/vienna'),
  ('Long Run', 'adidas Runners Vienna', 'laufen', 6, '08:30', '10:00',
   'Runbase, Badeschiff, Schwedenplatz, Wien', 48.2131, 16.3789, 'Wien',
   'https://adidasrunners.adidas.com/community/vienna'),
  ('run2gether Lauftreff', 'run2gether', 'laufen', 4, '18:30', '19:30',
   'Stadionparkplatz, Prater Hauptallee, Wien', 48.2019, 16.4126, 'Wien',
   'https://www.run2gether.com/'),
  ('Lauftreff am Donnerstag', 'Auftakt', 'laufen', 4, '17:00', '18:00',
   'Meiereistraße/Prater Hauptallee, Stadionparkplatz, Wien', 48.2019, 16.4126, 'Wien',
   'https://www.auftakt-gmbh.at/lauftreff-am-donnerstag/');
