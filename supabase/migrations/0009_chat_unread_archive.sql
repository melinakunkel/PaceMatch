-- Unread-message tracking and archive/delete for chats.

alter table group_members add column if not exists last_read_at timestamptz;
alter table group_members add column if not exists archived boolean not null default false;

-- Needed so a group's creator can permanently delete it (leaving a group,
-- for non-creators, already worked via the existing DELETE policy on
-- group_members).
drop policy if exists "creator can delete group" on groups;
create policy "creator can delete group" on groups
  for delete using (auth.uid() = created_by);
