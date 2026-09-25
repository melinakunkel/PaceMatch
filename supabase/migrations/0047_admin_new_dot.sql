-- Red dot for the admin: has anything new come in (report, feedback,
-- account paused/deleted) since they last opened "Meldungen & Feedback"?
alter table profiles add column if not exists admin_seen_at timestamptz;

create or replace function public.admin_has_new()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  with me as (
    select coalesce(admin_seen_at, '-infinity'::timestamptz) as seen
    from profiles
    where id = auth.uid() and is_admin
  )
  select coalesce((
    select exists (select 1 from reports, me where reports.created_at > me.seen)
        or exists (select 1 from feedback, me where feedback.created_at > me.seen)
        or exists (select 1 from account_feedback, me where account_feedback.created_at > me.seen)
    from me
  ), false);
$$;

-- Admins can appoint and remove other admins from inside the app. Checked
-- here (security definer), since users can't touch is_admin through the
-- API themselves (see protect_moderation_fields in 0046). The last admin
-- can't remove themselves, so the app is never left without one.
create or replace function public.set_admin(target uuid, make_admin boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'only admins can change admins';
  end if;
  if not make_admin
     and (select count(*) from profiles where is_admin and id <> target) = 0 then
    raise exception 'last admin';
  end if;
  update profiles set is_admin = make_admin where id = target;
end;
$$;
