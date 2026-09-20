-- Test data: 7 fake users with profiles, sports and a mix of recurring +
-- one-off activities around Vienna, so Matches/Entdecken have something to
-- show. Safe to run multiple times (uses fixed UUIDs + upserts/deletes).
-- Run this in the Supabase SQL editor AFTER migrations 0001-0003.

-- Clean up any previous run of this seed (keeps it idempotent).
delete from auth.users where email like '%@samepace-demo.test';

do $$
declare
  u_anna    uuid := '11111111-1111-4111-8111-111111111101';
  u_david   uuid := '11111111-1111-4111-8111-111111111102';
  u_lisa    uuid := '11111111-1111-4111-8111-111111111103';
  u_jonas   uuid := '11111111-1111-4111-8111-111111111104';
  u_sophie  uuid := '11111111-1111-4111-8111-111111111105';
  u_michael uuid := '11111111-1111-4111-8111-111111111106';
  u_julia   uuid := '11111111-1111-4111-8111-111111111107';
begin
  -- 1. Auth users (triggers handle_new_user -> creates the profiles row).
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values
    ('00000000-0000-0000-0000-000000000000', u_anna, 'authenticated', 'authenticated',
     'anna@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Anna Gruber"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_david, 'authenticated', 'authenticated',
     'david@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"David Weber"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_lisa, 'authenticated', 'authenticated',
     'lisa@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Lisa Bauer"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_jonas, 'authenticated', 'authenticated',
     'jonas@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Jonas Novak"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_sophie, 'authenticated', 'authenticated',
     'sophie@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Sophie Wagner"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_michael, 'authenticated', 'authenticated',
     'michael@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Michael Huber"}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_julia, 'authenticated', 'authenticated',
     'julia@samepace-demo.test', crypt('demo-password-123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Julia Steiner"}',
     now(), now(), '', '', '', '');

  -- 2. Fill in age/gender/city on the auto-created profile rows.
  update profiles set age = 27, gender = 'weiblich',  city = 'Wien' where id = u_anna;
  update profiles set age = 31, gender = 'männlich',  city = 'Wien' where id = u_david;
  update profiles set age = 24, gender = 'weiblich',  city = 'Wien' where id = u_lisa;
  update profiles set age = 29, gender = 'männlich',  city = 'Wien' where id = u_jonas;
  update profiles set age = 35, gender = 'weiblich',  city = 'Wien' where id = u_sophie;
  update profiles set age = 42, gender = 'männlich',  city = 'Wien' where id = u_michael;
  update profiles set age = 26, gender = 'divers',    city = 'Wien' where id = u_julia;

  -- 3. Sports & levels shown on their profile.
  insert into user_sports (user_id, sport, level, unit, value_low, value_high) values
    (u_anna,    'laufen',     'Fortgeschritten', 'min_per_km', 5.0,  5.5),
    (u_david,   'laufen',     'Fortgeschritten', 'min_per_km', 4.83, 5.33),
    (u_david,   'radfahren',  'Profi',           'km_per_h',   27,   32),
    (u_lisa,    'schwimmen',  'Fortgeschritten', 'min_per_km', 22,   26),
    (u_jonas,   'laufen',     'Anfänger',        'min_per_km', 6.5,  7.5),
    (u_sophie,  'wandern',    'Fortgeschritten', 'min_per_km', 10,   14),
    (u_michael, 'radfahren',  'Fortgeschritten', 'km_per_h',   25,   28),
    (u_julia,   'tennis',     'Fortgeschritten', 'min_per_km', null, null);

  -- 4. Activities: a mix of weekly recurring slots and one-off dates,
  -- around real Vienna spots, so both Matches and Entdecken have content.
  insert into activities (
    user_id, sport, day_of_week, start_time, end_time, location_name,
    latitude, longitude, radius_km, distance_min_km, distance_max_km,
    pace_min, pace_max, specific_date
  ) values
    -- Recurring Sunday-evening runners near the Prater (likely to match
    -- whatever you've already entered there).
    (u_anna, 'laufen', 7, '18:00', '19:00', 'Prater, Wien',
     48.2141, 16.4053, 3, 5, 10, 5.0, 5.5, null),
    (u_david, 'laufen', 7, '18:15', '19:15', 'Prater, Wien',
     48.2141, 16.4053, 3, 6, 12, 4.83, 5.33, null),

    -- Other recurring slots across the week.
    (u_david, 'radfahren', 4, '17:30', '19:00', 'Donauinsel, Wien',
     48.2364, 16.4229, 5, 20, 40, 27, 32, null),
    (u_lisa, 'schwimmen', 2, '19:00', '20:00', 'Stadthallenbad, Wien',
     48.1959, 16.3364, 3, 1, 3, 22, 26, null),
    (u_lisa, 'schwimmen', 5, '07:00', '08:00', 'Stadthallenbad, Wien',
     48.1959, 16.3364, 3, 1, 3, 22, 26, null),
    (u_michael, 'radfahren', 6, '09:00', '11:00', 'Donaukanal, Wien',
     48.2132, 16.3789, 5, 30, 60, 25, 28, null),
    (u_julia, 'tennis', 7, '10:00', '11:30', 'Tennisplatz Prater, Wien',
     48.2158, 16.4021, 3, null, null, null, null, null),

    -- One-off dates (specific_date), day_of_week derived from the date so
    -- the two stay consistent.
    (u_jonas, 'laufen', extract(isodow from current_date + 2)::int, '18:30', '19:30',
     'Alte Donau, Wien', 48.2389, 16.4436, 3, 4, 8, 6.5, 7.5, current_date + 2),
    (u_sophie, 'wandern', extract(isodow from current_date + 5)::int, '09:00', '13:00',
     'Kahlenberg, Wien', 48.2634, 16.3167, 5, 10, 16, 10, 14, current_date + 5),
    (u_anna, 'laufen', extract(isodow from current_date + 1)::int, '06:30', '07:30',
     'Donauinsel, Wien', 48.2364, 16.4229, 3, 5, 8, 5.0, 5.5, current_date + 1);
end $$;

-- Sanity check.
select p.full_name, p.age, p.gender, a.sport, a.day_of_week, a.specific_date, a.start_time
from activities a
join profiles p on p.id = a.user_id
where p.id in (
  '11111111-1111-4111-8111-111111111101', '11111111-1111-4111-8111-111111111102',
  '11111111-1111-4111-8111-111111111103', '11111111-1111-4111-8111-111111111104',
  '11111111-1111-4111-8111-111111111105', '11111111-1111-4111-8111-111111111106',
  '11111111-1111-4111-8111-111111111107'
)
order by p.full_name;
