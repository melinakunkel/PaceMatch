-- group_members had no UPDATE policy. joinGroup() uses an upsert
-- (insert ... on conflict do update) so a second person can be added
-- without erroring if they were already a member — but Postgres requires
-- an UPDATE policy to exist for the ON CONFLICT DO UPDATE branch to be
-- permitted at all, even when no conflict actually occurs. Without it,
-- every insert through upsert() was rejected as an RLS violation.

drop policy if exists "members can be updated by self or creator" on group_members;
create policy "members can be updated by self or creator" on group_members
  for update using (
    auth.uid() = user_id
    or auth.uid() = (select created_by from groups where id = group_id)
  );
