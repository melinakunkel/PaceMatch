-- Per-account customization of the Home screen's sport-selection grid:
-- order (a list of sport names, in the chosen display order) and which
-- ones are hidden. Empty defaults mean "use the app's built-in order,
-- nothing hidden" — today's behavior, unchanged until someone customizes
-- it. A sport not present in home_sport_order (e.g. one added to the app
-- after the user last customized their layout) is appended at the end and
-- stays visible — see HomeLayout.resolve() in the Flutter app.
alter table profiles add column if not exists home_sport_order text[] not null default '{}';
alter table profiles add column if not exists home_hidden_sports text[] not null default '{}';
