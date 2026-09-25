-- Email to samepace@outlook.de for every new feedback, report and account
-- pause/deletion — sent straight from the database via Resend's API
-- (pg_net), no server needed.
--
-- One-time setup (not part of this file, run separately with your key):
--   select vault.create_secret('re_…your Resend API key…', 'resend_api_key');
-- The key stays encrypted in Supabase Vault. Without it, nothing is sent
-- and nothing breaks.

create extension if not exists pg_net;

create or replace function public.html_escape(t text)
returns text
language sql
immutable
as $$
  select replace(replace(replace(replace(coalesce(t, ''),
    '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- Sends one email to the operator. Never raises: a mail problem must not
-- stop the feedback/report itself from being saved.
create or replace function public.notify_admin_email(subject text, body_html text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text;
begin
  select decrypted_secret into api_key
  from vault.decrypted_secrets
  where name = 'resend_api_key'
  limit 1;
  if api_key is null then
    return;
  end if;
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || api_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'SAMEPACE <onboarding@resend.dev>',
      'to', jsonb_build_array('samepace@outlook.de'),
      'subject', subject,
      'html', body_html
    )
  );
exception when others then
  null;
end;
$$;

-- Only the triggers below may send mail — users must not be able to call
-- this through the API and spam the inbox.
revoke execute on function public.notify_admin_email(text, text) from public, anon, authenticated;

create or replace function public.email_on_feedback()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  who text;
  kind text;
begin
  select full_name into who from profiles where id = new.user_id;
  kind := case new.category
    when 'idea' then 'Idee' when 'bug' then 'Fehler'
    when 'praise' then 'Lob' else 'Sonstiges' end;
  perform notify_admin_email(
    'SAMEPACE Feedback (' || kind || ') von ' || coalesce(who, 'unbekannt'),
    '<p><b>' || html_escape(coalesce(who, 'unbekannt')) || '</b> · ' || kind || ' · '
      || to_char(new.created_at at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') || '</p>'
      || '<p style="white-space:pre-wrap">' || html_escape(new.message) || '</p>'
      || '<p style="color:#6B7A75">Alle Einträge: App → Profil → ⚙️ → Meldungen &amp; Feedback</p>'
  );
  return new;
end;
$$;

drop trigger if exists email_on_feedback on feedback;
create trigger email_on_feedback
  after insert on feedback
  for each row execute function public.email_on_feedback();

create or replace function public.email_on_report()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  reporter text;
  reported text;
  total int;
begin
  select full_name into reporter from profiles where id = new.reporter_id;
  select full_name, report_count into reported, total from profiles where id = new.reported_user_id;
  perform notify_admin_email(
    '⚠️ SAMEPACE Meldung: ' || coalesce(reported, 'unbekannt') || ' (' || new.reason || ')',
    '<p><b>' || html_escape(coalesce(reporter, 'unbekannt')) || '</b> hat <b>'
      || html_escape(coalesce(reported, 'unbekannt')) || '</b> gemeldet · '
      || to_char(new.created_at at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') || '</p>'
      || '<p>Grund: ' || html_escape(new.reason) || '</p>'
      || case when new.details is not null
           then '<p style="white-space:pre-wrap">' || html_escape(new.details) || '</p>' else '' end
      || '<p>Insgesamt ' || coalesce(total, 0) || '× gemeldet'
      || case when coalesce(total, 0) >= 3 then ' – automatisch gesperrt' else '' end || '.</p>'
      || '<p style="color:#6B7A75">Alle Einträge: App → Profil → ⚙️ → Meldungen &amp; Feedback</p>'
  );
  return new;
end;
$$;

-- Postgres runs triggers of the same kind in name order: "zz_" makes this
-- run after "on_report_created", so the email shows the updated count.
drop trigger if exists zz_email_on_report on reports;
create trigger zz_email_on_report
  after insert on reports
  for each row execute function public.email_on_report();

create or replace function public.email_on_account_feedback()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  who text;
  what text;
begin
  select full_name into who from profiles where id = new.user_id;
  what := case when new.action = 'delete' then 'Konto gelöscht' else 'Konto pausiert' end;
  perform notify_admin_email(
    'SAMEPACE: ' || what || ' (' || coalesce(who, 'unbekannt') || ')',
    '<p><b>' || html_escape(coalesce(who, 'unbekannt')) || '</b> · ' || what || ' · '
      || to_char(new.created_at at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') || '</p>'
      || '<p style="white-space:pre-wrap">Grund: '
      || html_escape(coalesce(new.reason, 'kein Grund angegeben')) || '</p>'
  );
  return new;
end;
$$;

drop trigger if exists email_on_account_feedback on account_feedback;
create trigger email_on_account_feedback
  after insert on account_feedback
  for each row execute function public.email_on_account_feedback();
