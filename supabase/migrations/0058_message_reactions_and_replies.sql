-- Chat like WhatsApp: react to a message with an emoji (one reaction per
-- person and message) and reply to a specific message.

alter table messages add column if not exists reply_to uuid references messages (id) on delete set null;

-- A reply can only quote a message from the same chat.
create or replace function public.check_message_reply()
returns trigger
language plpgsql
as $$
begin
  if new.reply_to is not null and not exists (
    select 1 from messages m where m.id = new.reply_to and m.group_id = new.group_id
  ) then
    new.reply_to := null;
  end if;
  return new;
end;
$$;

drop trigger if exists check_message_reply on messages;
create trigger check_message_reply
  before insert on messages
  for each row execute function public.check_message_reply();

create table if not exists message_reactions (
  message_id uuid not null references messages (id) on delete cascade,
  group_id uuid not null references groups (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
create index if not exists message_reactions_group_idx on message_reactions (group_id);
alter table message_reactions enable row level security;

drop policy if exists "chat members see reactions" on message_reactions;
create policy "chat members see reactions" on message_reactions
  for select using (is_group_member(group_id, auth.uid()));

drop policy if exists "chat members react" on message_reactions;
create policy "chat members react" on message_reactions
  for insert with check (
    auth.uid() = user_id
    and is_group_member(group_id, auth.uid())
    and exists (
      select 1 from messages m
      where m.id = message_id and m.group_id = message_reactions.group_id
    )
  );

drop policy if exists "chat members change own reaction" on message_reactions;
create policy "chat members change own reaction" on message_reactions
  for update using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and is_group_member(group_id, auth.uid())
    and exists (
      select 1 from messages m
      where m.id = message_id and m.group_id = message_reactions.group_id
    )
  );

drop policy if exists "chat members remove own reaction" on message_reactions;
create policy "chat members remove own reaction" on message_reactions
  for delete using (auth.uid() = user_id);

-- Live updates in the open chat; "full" so removed reactions carry their
-- chat id and reach the right chat.
alter table message_reactions replica identity full;
alter publication supabase_realtime add table message_reactions;
