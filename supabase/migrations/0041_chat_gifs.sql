-- GIFs in chat: a message can carry a GIF from GIPHY. Only GIPHY's own
-- media hosts are allowed, so the chat can't be used to embed arbitrary
-- images (e.g. tracking pixels). content holds a short "GIF" fallback text.
alter table messages add column if not exists gif_url text;

alter table messages drop constraint if exists messages_gif_url_giphy;
alter table messages add constraint messages_gif_url_giphy
  check (gif_url is null or gif_url ~ '^https://media[0-9]*\.giphy\.com/');
