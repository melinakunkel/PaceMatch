-- Feedback round 3:
-- * Several "Ruhezeiten" per person (e.g. nap + night), read by the Edge
--   Function "push". The older single window is copied over.
-- * Optional link to someone's Strava profile.
-- * Sensible default "Umkreis" per sport: sport times still on the old
--   blanket 3 km get their sport's typical distance (cycling 15 km, ...).

alter table profiles add column if not exists push_quiet_windows jsonb not null default '[]'::jsonb;

update profiles
set push_quiet_windows = jsonb_build_array(jsonb_build_object(
  'start', to_char(push_quiet_start, 'HH24:MI'),
  'end', to_char(push_quiet_end, 'HH24:MI')
))
where push_quiet_start is not null
  and push_quiet_end is not null
  and push_quiet_windows = '[]'::jsonb;

alter table profiles add column if not exists strava_url text;
alter table profiles drop constraint if exists profiles_strava_url_check;
alter table profiles add constraint profiles_strava_url_check check (
  strava_url is null
  or strava_url ~ '^https://(www\.)?strava\.com/'
  or strava_url ~ '^https://strava\.app\.link/'
);

update activities
set radius_km = case sport::text
  when 'radfahren' then 15
  when 'wandern' then 15
  when 'beachvolleyball' then 10
  when 'bouldern' then 8
  when 'padel' then 8
  when 'badminton' then 8
  when 'hundeGassi' then 2
  when 'kinderSpielen' then 3
  when 'schwangerschaftssport' then 3
  else 5
end
where radius_km = 3;
