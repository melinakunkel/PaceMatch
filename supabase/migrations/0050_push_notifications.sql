-- Real push notifications on the phone (Web Push), also when SAMEPACE is
-- closed. The database tells the Edge Function "push" about new messages,
-- Sportbuddys and chat requests; the function sends them to every device
-- the recipient turned push on for.
--
-- Needs the Edge Function "push" (supabase/functions/push/index.ts)
-- deployed with "Enforce JWT verification" turned OFF. Until it is, the
-- calls below simply fail quietly — nothing else is affected.

create extension if not exists pg_net;

-- One row per device/browser that turned push on. The endpoint is the
-- device's secret push address.
create table if not exists push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user_idx on push_subscriptions (user_id);
alter table push_subscriptions enable row level security;

drop policy if exists "users see own push subscriptions" on push_subscriptions;
create policy "users see own push subscriptions" on push_subscriptions
  for select using (auth.uid() = user_id);

-- Saving goes through this function so a device that was used by another
-- account before is simply moved over to whoever is logged in now.
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
  if sub_endpoint !~ '^https://' or length(sub_endpoint) > 1000
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

-- Knowing the endpoint (only the device itself does) is enough to remove
-- it — used when push is turned off or on logout.
create or replace function public.delete_push_subscription(sub_endpoint text)
returns void
language sql
security definer set search_path = public
as $$
  delete from push_subscriptions where endpoint = sub_endpoint;
$$;

revoke execute on function public.save_push_subscription(text, text, text) from public, anon;
revoke execute on function public.delete_push_subscription(text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;
grant execute on function public.delete_push_subscription(text) to authenticated;

-- Where to reach the function and the shared secret it checks. The VAPID
-- keys are filled in by the function itself on first use. RLS without
-- policies: nobody can read this through the API.
create table if not exists push_config (
  id int primary key default 1 check (id = 1),
  function_url text not null,
  webhook_secret text not null,
  vapid_public_key text,
  vapid_private_jwk jsonb
);
alter table push_config enable row level security;

insert into push_config (function_url, webhook_secret)
values (
  'https://qxixdqhqvrhiwfoxecpq.supabase.co/functions/v1/push',
  replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
)
on conflict (id) do nothing;

-- Hands one event to the function. Never raises: a push problem must never
-- stop a message, like or request from being saved.
create or replace function public.send_push_event(event jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  cfg push_config;
begin
  select * into cfg from push_config where id = 1;
  if not found then
    return;
  end if;
  perform net.http_post(
    url := cfg.function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', cfg.webhook_secret
    ),
    body := event
  );
exception when others then
  null;
end;
$$;

revoke execute on function public.send_push_event(jsonb) from public, anon, authenticated;

create or replace function public.push_on_message()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Only bother the function when someone in this chat has push on.
  if exists (
    select 1
    from group_members gm
    join push_subscriptions ps on ps.user_id = gm.user_id
    where gm.group_id = new.group_id and gm.user_id <> new.sender_id
  ) then
    perform send_push_event(jsonb_build_object('type', 'message', 'id', new.id));
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_message on messages;
create trigger push_on_message
  after insert on messages
  for each row execute function public.push_on_message();

-- like_user() writes one match_events row per side; only the other person
-- needs a push (the one who just tapped already sees it on screen).
create or replace function public.push_on_match()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.user_id is distinct from auth.uid()
     and exists (select 1 from push_subscriptions where user_id = new.user_id) then
    perform send_push_event(jsonb_build_object(
      'type', 'match',
      'user_id', new.user_id,
      'other_user_id', new.other_user_id
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_match on match_events;
create trigger push_on_match
  after insert on match_events
  for each row execute function public.push_on_match();

create or replace function public.push_on_chat_request()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (select 1 from push_subscriptions where user_id = new.to_user) then
    perform send_push_event(jsonb_build_object(
      'type', 'chat_request',
      'from_user', new.from_user,
      'to_user', new.to_user
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists push_on_chat_request on chat_requests;
create trigger push_on_chat_request
  after insert on chat_requests
  for each row execute function public.push_on_chat_request();
