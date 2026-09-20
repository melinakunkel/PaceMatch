-- Fixes "infinite recursion detected in policy" (Postgres error 42P17).
--
-- The group_members SELECT policy queried group_members itself to check
-- membership, and the groups/messages policies queried group_members too —
-- so anything touching groups, group_members or messages re-triggered the
-- same recursive check. A SECURITY DEFINER helper function breaks the loop:
-- its body runs with elevated privileges and bypasses RLS, so it can check
-- membership without re-invoking the policy that's calling it.

create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from group_members
    where group_id = p_group_id and user_id = p_user_id
  );
$$;

drop policy if exists "members viewable by group members" on group_members;
create policy "members viewable by group members" on group_members
  for select using (is_group_member(group_id, auth.uid()));

drop policy if exists "groups viewable by members" on groups;
create policy "groups viewable by members" on groups
  for select using (
    auth.uid() = created_by or is_group_member(id, auth.uid())
  );

drop policy if exists "messages viewable by group members" on messages;
create policy "messages viewable by group members" on messages
  for select using (is_group_member(group_id, auth.uid()));

drop policy if exists "group members can send messages" on messages;
create policy "group members can send messages" on messages
  for insert with check (
    auth.uid() = sender_id and is_group_member(group_id, auth.uid())
  );
