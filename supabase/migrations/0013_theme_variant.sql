-- Theme choice synced to the account (in addition to local device storage)
-- so it survives logout/login and follows the user across browsers.
alter table profiles add column if not exists theme_variant text;
