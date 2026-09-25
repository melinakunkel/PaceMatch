-- Security fix from the code review:
--
-- 1. Anyone could add *themselves* to any chat whose id they knew — even a
--    private one — and then read all its messages. Now joining on your own
--    only works for open events (that's their purpose, and full events
--    stay closed); every other chat can only be filled by its creator.
--
--    A private (1:1) chat never gets a third person — not even from its
--    creator — and nobody can make themselves a chat's creator or turn a
--    private chat into a group.
--
-- 2. Push subscriptions are only accepted for the real browser push
--    services, so the Edge Function can't be pointed at arbitrary URLs.

-- Counts members regardless of who asks (a non-member can't see them
-- through RLS, so a plain count would always be 0).
create or replace function public.group_member_count(p_group_id uuid)
returns int
language sql
security definer set search_path = public
stable
as $$
  select count(*)::int from group_members where group_id = p_group_id;
$$;

drop policy if exists "users can join a group or be added by its creator" on group_members;
create policy "users can join a group or be added by its creator" on group_members
  for insert with check (
    (
      auth.uid() = (select created_by from groups where id = group_id)
      and (
        not coalesce((select is_direct from groups where id = group_id), false)
        or group_member_count(group_id) < 2
      )
    )
    or (
      auth.uid() = user_id
      and exists (
        select 1 from open_events oe
        where oe.group_id = group_members.group_id
          and (
            oe.max_participants is null
            or group_member_count(oe.group_id) < oe.max_participants
          )
      )
    )
  );

create or replace function public.protect_group_owner()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.created_by is distinct from old.created_by
          or new.is_direct is distinct from old.is_direct) then
    raise exception 'a chat''s creator and type cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_group_owner on groups;
create trigger protect_group_owner
  before update on groups
  for each row execute function public.protect_group_owner();

create or replace function public.save_push_subscription(
  sub_endpoint text,
  sub_p256dh text,
  sub_auth text
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not logged in';
  end if;
  if sub_endpoint !~ '^https://([a-z0-9-]+\.)*(fcm\.googleapis\.com|push\.services\.mozilla\.com|push\.apple\.com|notify\.windows\.com)/'
     or length(sub_endpoint) > 1000
     or length(sub_p256dh) > 200 or length(sub_auth) > 100 then
    raise exception 'invalid subscription';
  end if;
  insert into push_subscriptions (endpoint, user_id, p256dh, auth)
  values (sub_endpoint, auth.uid(), sub_p256dh, sub_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth = excluded.auth,
        created_at = now();
end;
$$;

-- Anything already stored that isn't a real push service goes.
delete from push_subscriptions
where endpoint !~ '^https://([a-z0-9-]+\.)*(fcm\.googleapis\.com|push\.services\.mozilla\.com|push\.apple\.com|notify\.windows\.com)/';
