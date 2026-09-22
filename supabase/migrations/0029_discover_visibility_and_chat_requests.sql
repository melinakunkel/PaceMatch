-- Per-activity control over how "Entdecken" exposes you: 'open' (shown,
-- directly contactable — today's behavior, kept as the default so existing
-- rows don't change), 'hidden' (not shown at all) or 'request' (shown, but
-- contacting first sends a request the other side must accept).
alter table activities add column if not exists discover_visibility text
  not null default 'open'
  check (discover_visibility in ('open', 'hidden', 'request'));

-- Pending "may we chat?" requests for a 'request'-visibility activity. A row
-- existing IS the pending state — accepting deletes it and creates the
-- group chat (client-side, same as the existing direct-contact flow);
-- declining just deletes it, so the sender can freely try again later.
create table if not exists chat_requests (
  from_user uuid not null references profiles (id) on delete cascade,
  to_user uuid not null references profiles (id) on delete cascade,
  activity_id uuid not null references activities (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user, activity_id),
  check (from_user <> to_user)
);
alter table chat_requests enable row level security;

create policy "users see requests involving them" on chat_requests
  for select using (auth.uid() = from_user or auth.uid() = to_user);

create policy "users send their own requests" on chat_requests
  for insert with check (
    auth.uid() = from_user
    and not exists (
      select 1 from blocks
      where (blocker_id = auth.uid() and blocked_id = to_user)
         or (blocker_id = to_user and blocked_id = auth.uid())
    )
  );

create policy "users remove requests involving them" on chat_requests
  for delete using (auth.uid() = from_user or auth.uid() = to_user);
