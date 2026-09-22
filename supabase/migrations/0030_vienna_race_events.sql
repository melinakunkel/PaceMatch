-- Bigger, one-off Vienna race-style events (marathon, business run,
-- triathlon, night run) alongside the existing weekly run-club meetups —
-- so the new "all events" timeline view has more than just recurring club
-- sessions to show. Dates are relative to whenever this runs (current_date
-- + N), same convention as the one-off activities in seed_dummy_users.sql,
-- since we can't pin a verified real-world date/URL from here — check the
-- official sites before this goes fully live.
insert into community_events (name, source, sport, specific_date, start_time, end_time, location_name, latitude, longitude, city, url) values
  ('Vienna City Marathon', 'Wien Energie Vienna City Marathon', 'laufen', current_date + 10, '09:00', '13:00',
   'Prater Hauptallee / Ringstraße, Wien', 48.2082, 16.3738, 'Wien',
   'https://www.vienna-marathon.com/'),
  ('Wien Energie Business Run', 'Wien Energie Business Run', 'laufen', current_date + 20, '18:00', '20:00',
   'Prater Hauptallee, Wien', 48.2019, 16.4126, 'Wien',
   'https://www.businessrun.at/'),
  ('Vienna Triathlon', 'Vienna Triathlon', 'sonstige', current_date + 35, '08:00', '14:00',
   'Alte Donau, Wien', 48.2389, 16.4436, 'Wien', null),
  ('Nachtlauf Wien', null, 'laufen', current_date + 50, '20:00', '22:00',
   'Ringstraße, Wien', 48.2082, 16.3738, 'Wien', null);
