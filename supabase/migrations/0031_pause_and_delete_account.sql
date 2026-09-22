-- Pausing hides the account from matching/discovery without deleting
-- anything — logging back in reactivates it automatically (see the app's
-- login flow). Deleting is permanent.
alter table profiles add column if not exists paused_at timestamptz;

-- Why someone paused or deleted, for product feedback. No foreign key to
-- profiles: for a deletion, the profile row is gone moments after this is
-- written (auth.users cascades), and this row must survive that.
create table if not exists account_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  action text not null check (action in ('pause', 'delete')),
  reason text,
  created_at timestamptz not null default now()
);
alter table account_feedback enable row level security;

create policy "users submit their own feedback" on account_feedback
  for insert with check (auth.uid() = user_id);

-- Deletes the caller's account entirely: the auth.users row and everything
-- that cascades from it (profile, activities, likes, messages, ...).
-- security definer because the authenticated role can't reach into the
-- auth schema directly.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;
