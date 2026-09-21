-- Blocking only filtered future matches/discovery — an existing shared chat
-- kept working until the next reload happened to exclude the other person,
-- so you could still write to someone you'd just blocked. block_user() now
-- does both atomically: record the block and remove me from any group I
-- currently share with them, so the chat is gone and RLS (which requires
-- group membership to read or send) stops me from reaching them right away.
create or replace function public.block_user(target uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into blocks (blocker_id, blocked_id)
  values (auth.uid(), target)
  on conflict (blocker_id, blocked_id) do nothing;

  delete from group_members
  where user_id = auth.uid()
    and group_id in (
      select group_id from group_members where user_id = target
    );
end;
$$;
