-- Short Hinge-style Q&A prompts shown on a profile, stored as a JSON array
-- of {"q": question, "a": answer} objects.
alter table profiles add column if not exists prompts jsonb not null default '[]';
