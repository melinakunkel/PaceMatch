-- Circle descriptions, member roles, and admin management: a circle's
-- creator can now share management (edit name/description, remove members,
-- promote/demote admins) with other members instead of being the only one
-- who can touch it.

alter table circles add column description text;

alter table circle_members add column role text not null default 'member';

alter table circle_members add constraint circle_members_role_check
  check (role in ('admin', 'member'));

update circle_members cm
set role = 'admin'
from circles c
where c.id = cm.circle_id and c.created_by = cm.user_id;

create function public.is_circle_admin(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from circle_members
    where circle_id = p_circle_id and user_id = p_user_id and role = 'admin'
  );
$$;

drop policy "creator can update circle" on circles;
create policy "admins can update circle" on circles
  for update using (
    auth.uid() = created_by or is_circle_admin(id, auth.uid())
  );

create policy "admins can update member roles" on circle_members
  for update using (is_circle_admin(circle_id, auth.uid()));

create policy "admins can remove members" on circle_members
  for delete using (is_circle_admin(circle_id, auth.uid()));
