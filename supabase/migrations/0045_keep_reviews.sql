-- Reviews must outlive the chat they were given in. Before, deleting a
-- private chat (which now happens as soon as one person leaves) deleted its
-- reviews too — so someone who didn't show up could leave the chat and make
-- the bad review disappear from their score.

-- The chat link becomes optional and is cleared instead of deleting the
-- review. The composite key can't contain a nullable column, so it becomes
-- a unique constraint with its own id as primary key.
alter table meetup_reviews add column if not exists id uuid not null default gen_random_uuid();
alter table meetup_reviews drop constraint if exists meetup_reviews_pkey;
alter table meetup_reviews add primary key (id);
alter table meetup_reviews drop constraint if exists meetup_reviews_one_per_meetup;
alter table meetup_reviews add constraint meetup_reviews_one_per_meetup
  unique (group_id, reviewer_id, reviewee_id, meeting_time);
alter table meetup_reviews alter column group_id drop not null;
alter table meetup_reviews drop constraint if exists meetup_reviews_group_id_fkey;
alter table meetup_reviews add constraint meetup_reviews_group_id_fkey
  foreign key (group_id) references groups (id) on delete set null;

-- Recompute on delete too (e.g. a reviewer deleting their account), so the
-- score never keeps counting reviews that no longer exist.
create or replace function public.handle_meetup_review()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform recompute_reliability(coalesce(new.reviewee_id, old.reviewee_id));
  return null;
end;
$$;

drop trigger if exists on_meetup_review on meetup_reviews;
create trigger on_meetup_review
  after insert or update or delete on meetup_reviews
  for each row execute function public.handle_meetup_review();

-- Bring every score in line with the reviews that actually exist.
select recompute_reliability(id) from profiles;
