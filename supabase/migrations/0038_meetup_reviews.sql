-- Peer reviews after a meetup: the other participants say whether someone
-- showed up and whether their details (pace, level, ...) matched. Anonymous:
-- only the reviewer can read their own reviews; they only feed into the
-- reviewee's reliability_score, which is now computed from these instead of
-- the person's own check-in.

create table if not exists meetup_reviews (
  group_id uuid not null references groups (id) on delete cascade,
  reviewer_id uuid not null references profiles (id) on delete cascade,
  reviewee_id uuid not null references profiles (id) on delete cascade,
  showed_up boolean not null,
  details_matched boolean,
  mismatches text[] not null default '{}',
  created_at timestamptz not null default now(),
  primary key (group_id, reviewer_id, reviewee_id),
  check (reviewer_id <> reviewee_id)
);

alter table meetup_reviews enable row level security;

drop policy if exists "reviewers see own reviews" on meetup_reviews;
create policy "reviewers see own reviews" on meetup_reviews
  for select using (auth.uid() = reviewer_id);

drop policy if exists "members review each other" on meetup_reviews;
create policy "members review each other" on meetup_reviews
  for insert with check (
    auth.uid() = reviewer_id
    and is_group_member(group_id, auth.uid())
    and is_group_member(group_id, reviewee_id)
  );

drop policy if exists "reviewers update own reviews" on meetup_reviews;
create policy "reviewers update own reviews" on meetup_reviews
  for update using (auth.uid() = reviewer_id)
  with check (
    auth.uid() = reviewer_id
    and is_group_member(group_id, reviewee_id)
  );

-- reliability_score = average over all reviews received: no-show 0,
-- showed up but details didn't match 0.5, all good 1. No reviews = 100.
create or replace function public.recompute_reliability(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  s numeric;
begin
  select coalesce(
    avg(case
      when not showed_up then 0
      when details_matched is false then 0.5
      else 1
    end) * 100,
    100
  )
  into s
  from meetup_reviews
  where reviewee_id = p_user;

  perform set_config('samepace.score_update', 'on', true);
  update profiles set reliability_score = round(s, 1) where id = p_user;
  perform set_config('samepace.score_update', 'off', true);
end;
$$;

create or replace function public.handle_meetup_review()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform recompute_reliability(new.reviewee_id);
  return new;
end;
$$;

drop trigger if exists on_meetup_review on meetup_reviews;
create trigger on_meetup_review
  after insert or update on meetup_reviews
  for each row execute function public.handle_meetup_review();

-- Users can update their own profile row, so without this they could set
-- their own reliability_score via the API. Only recompute_reliability may
-- change it.
create or replace function public.protect_reliability_score()
returns trigger
language plpgsql
as $$
begin
  if new.reliability_score is distinct from old.reliability_score
     and coalesce(current_setting('samepace.score_update', true), 'off') <> 'on' then
    new.reliability_score := old.reliability_score;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_reliability_score on profiles;
create trigger protect_reliability_score
  before update on profiles
  for each row execute function public.protect_reliability_score();

-- Existing scores came from self-reported check-ins; start everyone fresh.
select set_config('samepace.score_update', 'on', false);
update profiles set reliability_score = 100;
select set_config('samepace.score_update', 'off', false);
