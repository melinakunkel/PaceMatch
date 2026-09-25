-- Tester protocols from test.html land in the admin view's Feedback tab.
-- Testers may not be logged in on that page, so they're sent through a
-- function that anyone can call, with a size limit and a global rate limit
-- against spam.
alter table feedback add column if not exists author_name text;

alter table feedback drop constraint if exists feedback_category_check;
alter table feedback add constraint feedback_category_check
  check (category in ('idea', 'bug', 'praise', 'other', 'test'));

alter table feedback drop constraint if exists feedback_message_check;
alter table feedback add constraint feedback_message_check
  check (length(message) between 1 and 20000);

create or replace function public.submit_test_protocol(tester_name text, protocol text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if protocol is null or length(trim(protocol)) = 0 or length(protocol) > 20000 then
    raise exception 'invalid protocol';
  end if;
  if (select count(*) from feedback
      where category = 'test' and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'too many submissions, try again later';
  end if;
  insert into feedback (user_id, category, message, author_name)
  values (auth.uid(), 'test', protocol, left(nullif(trim(tester_name), ''), 80));
end;
$$;

grant execute on function public.submit_test_protocol(text, text) to anon, authenticated;
