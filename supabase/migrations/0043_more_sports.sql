-- New sports: Bouldern, Badminton, Tischtennis, Beachvolleyball. `sport` is
-- the Postgres enum sport_type, so every sport in the app needs its value
-- here too — otherwise saving a sport time fails with "invalid input value
-- for enum sport_type". ('sonstige' stays for old data; the app just no
-- longer offers it.)
alter type sport_type add value if not exists 'bouldern';
alter type sport_type add value if not exists 'badminton';
alter type sport_type add value if not exists 'tischtennis';
alter type sport_type add value if not exists 'beachvolleyball';
