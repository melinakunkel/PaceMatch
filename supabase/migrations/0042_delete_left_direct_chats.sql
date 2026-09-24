-- A private chat is only between two people: as soon as one of them leaves
-- (leaving, blocking, deleting their account), it's deleted for the other
-- person too, messages included. Exception: a chat someone reported stays,
-- so the report's messages are still there for review.

create or replace function public.delete_left_direct_chat()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  delete from groups g
  where g.id = old.group_id
    and g.is_direct
    and not exists (select 1 from reports r where r.group_id = g.id);
  return null;
end;
$$;

drop trigger if exists on_direct_chat_member_left on group_members;
create trigger on_direct_chat_member_left
  after delete on group_members
  for each row execute function public.delete_left_direct_chat();

-- Clean up private chats someone already left before this.
delete from groups g
where g.is_direct
  and (select count(*) from group_members m where m.group_id = g.id) < 2
  and not exists (select 1 from reports r where r.group_id = g.id);
