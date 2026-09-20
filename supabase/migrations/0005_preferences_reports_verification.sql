-- Matching preferences (gender/age), a lightweight abuse-reporting table,
-- and a placeholder "verified" flag on profiles.

alter table profiles add column if not exists gender_preference text;
alter table profiles add column if not exists age_range_min int;
alter table profiles add column if not exists age_range_max int;
alter table profiles add column if not exists is_verified boolean not null default false;

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles (id) on delete cascade,
  reported_user_id uuid not null references profiles (id) on delete cascade,
  group_id uuid references groups (id) on delete set null,
  reason text not null,
  details text,
  created_at timestamptz not null default now()
);

alter table reports enable row level security;

drop policy if exists "users can create reports" on reports;
create policy "users can create reports" on reports
  for insert with check (auth.uid() = reporter_id);

drop policy if exists "users can view own reports" on reports;
create policy "users can view own reports" on reports
  for select using (auth.uid() = reporter_id);
