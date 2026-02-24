-- 22_follow_reads.sql
BEGIN;

-- =========================================================
-- Follows READS
-- =========================================================

-- 1) Проверка: подписан ли follower на following
CREATE OR REPLACE FUNCTION follow_is_following(
  p_follower_id uuid,
  p_following_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM user_follows f
    WHERE f.follower_id = p_follower_id
      AND f.following_id = p_following_id
  );
$$;


-- 2) Список "я подписан(а) на" (following) с карточками пользователей
--    Keyset пагинация: (created_at, following_id) DESC
CREATE OR REPLACE FUNCTION follow_list_following(
  p_follower_id uuid,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_following_id uuid DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  followed_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    f.created_at AS followed_at
  FROM user_follows f
  JOIN users u ON u.id = f.following_id
  WHERE f.follower_id = p_follower_id
    AND (
      p_cursor_created_at IS NULL
      OR (
          f.created_at < p_cursor_created_at
          OR (
          f.created_at = p_cursor_created_at
          AND (p_cursor_following_id IS NULL OR f.following_id < p_cursor_following_id)
          )
      )
    )
  ORDER BY f.created_at DESC, f.following_id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;


-- 3) Список "на меня подписаны" (followers) с карточками пользователей
--    Keyset пагинация: (created_at, follower_id) DESC
CREATE OR REPLACE FUNCTION follow_list_followers(
  p_following_id uuid,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_follower_id uuid DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  followed_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    f.created_at AS followed_at
  FROM user_follows f
  JOIN users u ON u.id = f.follower_id
  WHERE f.following_id = p_following_id
    AND (
      p_cursor_created_at IS NULL
      OR (
          f.created_at < p_cursor_created_at
          OR (
          f.created_at = p_cursor_created_at
          AND (p_cursor_follower_id IS NULL OR f.follower_id < p_cursor_follower_id)
          )
      )
    )
  ORDER BY f.created_at DESC, f.follower_id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;

COMMIT;
