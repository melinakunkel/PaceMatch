-- Admin view for the operator: in-app feedback, user reports and why people
-- paused/deleted their account, readable only by admins. Also closes a gap:
-- users could set is_verified / is_suspended / report_count on their own
-- profile through the API.

-- 1) Admin flag — only settable from the SQL editor, never through the API.
alter table profiles add column if not exists is_admin boolean not null default false;

-- Moderation fields can't be changed by users themselves. The API runs as
-- the "authenticated" role; security definer functions (like the report
-- trigger) and the SQL editor run as the owner and may still change them.
create or replace function public.protect_moderation_fields()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.is_admin := old.is_admin;
    new.is_verified := old.is_verified;
    new.is_suspended := old.is_suspended;
    new.report_count := old.report_count;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_moderation_fields on profiles;
create trigger protect_moderation_fields
  before update on profiles
  for each row execute function public.protect_moderation_fields();

create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;

-- 2) In-app feedback (instead of only an email link).
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles (id) on delete set null,
  category text not null check (category in ('idea', 'bug', 'praise', 'other')),
  message text not null check (length(message) between 1 and 4000),
  status text not null default 'new' check (status in ('new', 'done')),
  created_at timestamptz not null default now()
);
alter table feedback enable row level security;

drop policy if exists "users send feedback" on feedback;
create policy "users send feedback" on feedback
  for insert with check (auth.uid() = user_id);

drop policy if exists "admins read feedback" on feedback;
create policy "admins read feedback" on feedback
  for select using (is_admin());

drop policy if exists "admins update feedback" on feedback;
create policy "admins update feedback" on feedback
  for update using (is_admin()) with check (is_admin());

-- 3) Reports: admins can read all and mark them as handled.
alter table reports add column if not exists status text not null default 'new';

drop policy if exists "admins read reports" on reports;
create policy "admins read reports" on reports
  for select using (is_admin());

drop policy if exists "admins update reports" on reports;
create policy "admins update reports" on reports
  for update using (is_admin()) with check (is_admin());

-- 4) Why people paused/deleted their account.
drop policy if exists "admins read account feedback" on account_feedback;
create policy "admins read account feedback" on account_feedback
  for select using (is_admin());

-- 5) Make Melina the admin.
update profiles set is_admin = true where id = '688c11fc-1893-49de-bb39-aefaf74f8ee9';
