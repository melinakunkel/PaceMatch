-- Tracks who a user has passed on (left-swiped) for a specific activity, so
-- they don't reappear in the swipe queue after reopening the screen — while
-- still being visible in the list view, since only a like should ever hide
-- someone for good (see 0024/0025 for the same idea applied to likes).
create table if not exists activity_passes (
  user_id uuid not null references profiles (id) on delete cascade,
  target_id uuid not null references profiles (id) on delete cascade,
  activity_id uuid not null references activities (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, target_id, activity_id)
);
alter table activity_passes enable row level security;

create policy "users manage own passes" on activity_passes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
