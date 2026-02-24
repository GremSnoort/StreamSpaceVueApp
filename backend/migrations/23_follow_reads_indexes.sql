-- 23_follow_reads_indexes.sql
BEGIN;

-- Под keyset пагинацию добавляем "tie-breaker" id вторым ключом.
-- (Старые индексы из 20_follows.sql можно оставить — они полезны для других запросов.)

CREATE INDEX IF NOT EXISTS idx_user_follows_follower_created_following
  ON user_follows(follower_id, created_at DESC, following_id DESC);

CREATE INDEX IF NOT EXISTS idx_user_follows_following_created_follower
  ON user_follows(following_id, created_at DESC, follower_id DESC);

COMMIT;
