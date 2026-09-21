-- Lets a swipe be undone: removes a like the caller sent, but only while
-- it's still one-directional — once the other side has also liked back
-- (a completed match), undo no longer applies and this silently no-ops.
create or replace function public.unlike_user(target uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  delete from likes
  where from_user = auth.uid()
    and to_user = target
    and not exists (
      select 1 from likes where from_user = target and to_user = auth.uid()
    );
end;
$$;

-- Saved/"favorite" locations (e.g. a usual running loop or gym) so a new
-- activity's location doesn't need to be searched on the map every time.
create table if not exists saved_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);
alter table saved_locations enable row level security;

create policy "users manage own saved locations" on saved_locations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
