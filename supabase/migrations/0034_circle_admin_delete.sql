-- Lets any admin (not just the circle's original creator) delete it — the
-- 0033 restriction to creator-only turned out to be unwanted: an admin
-- should be able to fully manage a circle, deletion included.

drop policy "admins can update circle" on circles;
create policy "admins can update circle" on circles
  for update using (is_circle_admin(id, auth.uid()));

drop policy "creator can delete circle" on circles;
create policy "admins can delete circle" on circles
  for delete using (is_circle_admin(id, auth.uid()));
