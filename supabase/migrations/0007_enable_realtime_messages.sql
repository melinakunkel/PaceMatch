-- The chat screen subscribes to messages via Supabase Realtime
-- (.stream()), which only delivers rows for tables added to the
-- supabase_realtime publication. Without this, the stream just sits
-- open forever with no data — the chat looked like it was stuck loading.

alter publication supabase_realtime add table messages;
