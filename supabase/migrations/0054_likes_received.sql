-- "Wer hat dich geliked" (free for now): people who liked me and whom I
-- haven't liked back yet. Until now this was deliberately hidden (see
-- get_buddies in 0024); it's shown on purpose now so matches don't get
-- missed while the app is small. Suspended, paused and blocked people are
-- left out, and only mine can be read.

create or replace function public.get_likes_received()
returns table (liker_id uuid, liked_at timestamptz, activity_id uuid)
language sql
security definer set search_path = public
stable
as $$
  select l.from_user, l.created_at, l.activity_id
  from likes l
  join profiles p on p.id = l.from_user
  where l.to_user = auth.uid()
    and not exists (
      select 1 from likes back
      where back.from_user = auth.uid() and back.to_user = l.from_user
    )
    and not p.is_suspended
    and p.paused_at is null
    and not exists (
      select 1 from blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = l.from_user)
         or (b.blocker_id = l.from_user and b.blocked_id = auth.uid())
    )
  order by l.created_at desc
  limit 100;
$$;

revoke execute on function public.get_likes_received() from public, anon;
grant execute on function public.get_likes_received() to authenticated;
