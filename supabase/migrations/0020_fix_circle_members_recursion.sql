-- Fixes "infinite recursion detected in policy" (Postgres error 42P17) for
-- circle_members — the same issue group_members had, fixed the same way in
-- 0004: the SELECT policy queried circle_members itself to check
-- membership, and the circles/activities policies queried circle_members
-- too, so anything touching circles, circle_members or activities
-- re-triggered the same recursive check. A SECURITY DEFINER helper
-- function breaks the loop: its body runs with elevated privileges and
-- bypasses RLS, so it can check membership without re-invoking the policy
-- that's calling it.

create or replace function public.is_circle_member(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from circle_members
    where circle_id = p_circle_id and user_id = p_user_id
  );
$$;

drop policy if exists "members viewable by fellow members" on circle_members;
create policy "members viewable by fellow members" on circle_members
  for select using (is_circle_member(circle_id, auth.uid()));

drop policy if exists "circles viewable by members or creator" on circles;
create policy "circles viewable by members or creator" on circles
  for select using (
    auth.uid() = created_by or is_circle_member(id, auth.uid())
  );

drop policy if exists "activities are viewable by authenticated users" on activities;
create policy "activities are viewable by authenticated users" on activities
  for select using (
    circle_id is null or is_circle_member(circle_id, auth.uid())
  );
