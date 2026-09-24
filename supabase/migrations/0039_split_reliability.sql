-- Splits the reliability score into two public sub-scores: how often someone
-- shows up, and how often their details (pace, level, ...) matched. Null =
-- no reviews yet. Which details didn't match stays private: only the
-- reviewee can read their own breakdown, via my_review_summary().

alter table profiles add column if not exists attendance_score numeric;
alter table profiles add column if not exists accuracy_score numeric;

create or replace function public.recompute_reliability(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  total_score numeric;
  attendance numeric;
  accuracy numeric;
begin
  select
    coalesce(
      avg(case
        when not showed_up then 0
        when details_matched is false then 0.5
        else 1
      end) * 100,
      100
    ),
    avg(case when showed_up then 1 else 0 end) * 100,
    (avg(case when details_matched then 1 else 0 end)
      filter (where showed_up and details_matched is not null)) * 100
  into total_score, attendance, accuracy
  from meetup_reviews
  where reviewee_id = p_user;

  perform set_config('samepace.score_update', 'on', true);
  update profiles set
    reliability_score = round(total_score, 1),
    attendance_score = round(attendance, 1),
    accuracy_score = round(accuracy, 1)
  where id = p_user;
  perform set_config('samepace.score_update', 'off', true);
end;
$$;

-- Same guard as before, now covering the two sub-scores too.
create or replace function public.protect_reliability_score()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('samepace.score_update', true), 'off') <> 'on' then
    new.reliability_score := old.reliability_score;
    new.attendance_score := old.attendance_score;
    new.accuracy_score := old.accuracy_score;
  end if;
  return new;
end;
$$;

create or replace function public.my_review_summary()
returns json
language sql
security definer set search_path = public
stable
as $$
  select json_build_object(
    'total', count(*),
    'showed_up', count(*) filter (where showed_up),
    'rated_details', count(*) filter (where showed_up and details_matched is not null),
    'details_matched', count(*) filter (where showed_up and details_matched),
    'mismatches', coalesce(
      (select json_object_agg(m, c)
       from (
         select m, count(*) as c
         from meetup_reviews r, unnest(r.mismatches) as m
         where r.reviewee_id = auth.uid()
         group by m
       ) x),
      '{}'::json
    )
  )
  from meetup_reviews
  where reviewee_id = auth.uid();
$$;

-- Fill the new columns for anyone who already has reviews.
select recompute_reliability(id) from profiles;
