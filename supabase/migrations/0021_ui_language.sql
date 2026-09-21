-- The app's display language ('de' or 'en'), chosen at registration and
-- changeable later in Settings — separate from `languages`, which is the
-- languages a user is willing to meet up and chat in.
alter table profiles add column if not exists ui_language text not null default 'de';

-- Picks up the language chosen on the Register screen (passed through as
-- auth signup metadata, the same way full_name already is).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, ui_language)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Neue:r Nutzer:in'),
    coalesce(new.raw_user_meta_data ->> 'ui_language', 'de')
  );
  return new;
end;
$$;
