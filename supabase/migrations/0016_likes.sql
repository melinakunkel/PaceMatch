-- Tracks who swiped "like" on whom in Matches, so a like from both sides
-- can trigger an "It's a Match" moment instead of one side silently
-- creating a group chat.
create table if not exists likes (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references profiles (id) on delete cascade,
  to_user uuid not null references profiles (id) on delete cascade,
  activity_id uuid references activities (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (from_user, to_user)
);

create index if not exists likes_to_user_idx on likes (to_user);

alter table likes enable row level security;

drop policy if exists "users see likes involving them" on likes;
create policy "users see likes involving them" on likes
  for select using (auth.uid() = from_user or auth.uid() = to_user);

drop policy if exists "users create their own likes" on likes;
create policy "users create their own likes" on likes
  for insert with check (auth.uid() = from_user);
