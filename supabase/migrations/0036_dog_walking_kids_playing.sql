-- Two new "Sportarten" beyond exercise: Hunde spazieren (dog walking) and
-- Kinder spielen (kids playdate) — SAMEPACE's matching (same weekday, time
-- overlap) is just as useful for finding a dog-walking or playdate partner
-- as it is for a running buddy.

alter table activities add column has_dog boolean;
alter table activities add column child_age int;
alter table activities add column child_gender text;
