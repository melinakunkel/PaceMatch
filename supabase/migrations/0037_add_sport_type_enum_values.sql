-- `sport` is a native Postgres enum (sport_type), not plain text — adding
-- a new SportType in the app needs its value added here too, or saving an
-- activity/event with it fails with "invalid input value for enum
-- sport_type". Missed for hundeGassi/kinderSpielen when those were added;
-- adding padel here at the same time.

alter type sport_type add value if not exists 'hundeGassi';
alter type sport_type add value if not exists 'kinderSpielen';
alter type sport_type add value if not exists 'padel';
