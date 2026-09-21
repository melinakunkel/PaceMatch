-- 0027's block_user() only leaves a shared chat for blocks made from now on
-- — anyone blocked before that migration ran kept their existing chat, since
-- the old code just inserted into blocks without touching group_members.
-- Run the same cleanup once for every block already on record.
delete from group_members gm
using blocks b
where gm.user_id = b.blocker_id
  and gm.group_id in (
    select group_id from group_members where user_id = b.blocked_id
  );
