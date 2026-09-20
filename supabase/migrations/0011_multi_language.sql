-- Language preference is now multi-select (was a single value).
alter table profiles add column if not exists languages text[] not null default '{}';
alter table profiles drop column if exists language;
