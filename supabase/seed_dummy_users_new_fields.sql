-- Fills in the fields added since the original dummy-user seed: interests,
-- languages, and per-activity level/bike type/venue status. Updates the same
-- 7 demo users from seed_dummy_users.sql (run that one first if you haven't).
-- Plain statements, safe to run multiple times.

-- Interests & languages per profile.
update profiles set interests = array['Natur & Outdoor', 'Café & Brunch', 'Musik'], languages = array['de']
  where id = '11111111-1111-4111-8111-111111111101';
update profiles set interests = array['Gaming', 'Festivals & Konzerte', 'Ernährung'], languages = array['de', 'en']
  where id = '11111111-1111-4111-8111-111111111102';
update profiles set interests = array['Yoga & Meditation', 'Lesen', 'Reisen'], languages = array['de']
  where id = '11111111-1111-4111-8111-111111111103';
update profiles set interests = array['Filme & Serien', 'Kochen & Backen', 'Tiere'], languages = array['de', 'other']
  where id = '11111111-1111-4111-8111-111111111104';
update profiles set interests = array['Natur & Outdoor', 'Fotografie', 'Nachhaltigkeit'], languages = array['de', 'en']
  where id = '11111111-1111-4111-8111-111111111105';
update profiles set interests = array['Kunst & Kultur', 'Café & Brunch', 'Festivals & Konzerte'], languages = array['de']
  where id = '11111111-1111-4111-8111-111111111106';
update profiles set interests = array['Kunst & Kultur', 'Musik', 'Café & Brunch'], languages = array['de']
  where id = '11111111-1111-4111-8111-111111111107';

-- Bike type on the two radfahren activities.
update activities set bike_type = 'rennrad'
  where user_id = '11111111-1111-4111-8111-111111111102' and sport = 'radfahren';
update activities set bike_type = 'trekking'
  where user_id = '11111111-1111-4111-8111-111111111106' and sport = 'radfahren';

-- Level on the activities for sports without a numeric pace (matches what's
-- already set on their profile's user_sports row).
update activities set level = 'Fortgeschritten'
  where user_id = '11111111-1111-4111-8111-111111111105' and sport = 'wandern';
update activities set level = 'Fortgeschritten', venue_status = 'has_venue'
  where user_id = '11111111-1111-4111-8111-111111111107' and sport = 'tennis';

-- Bonus: one activity for the new Schwangerschafts-/Rückbildungssport type,
-- so there's something to see for it in Entdecken/Matches.
insert into activities (user_id, sport, day_of_week, start_time, end_time, location_name, latitude, longitude, radius_km, level, specific_date) values
  ('11111111-1111-4111-8111-111111111101', 'schwangerschaftssport', 3, '10:00', '11:00', 'Yogastudio Prater, Wien', 48.2145, 16.4030, 3, 'Anfänger', null);

-- Sanity check.
select p.full_name, p.languages, p.interests, a.sport, a.level, a.bike_type, a.venue_status
from profiles p
left join activities a on a.user_id = p.id
where p.id in (
  '11111111-1111-4111-8111-111111111101', '11111111-1111-4111-8111-111111111102',
  '11111111-1111-4111-8111-111111111103', '11111111-1111-4111-8111-111111111104',
  '11111111-1111-4111-8111-111111111105', '11111111-1111-4111-8111-111111111106',
  '11111111-1111-4111-8111-111111111107'
)
order by p.full_name;
