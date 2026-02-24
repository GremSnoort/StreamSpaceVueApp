-- 21_follow_functions.sql
BEGIN;

-- =========================================================
-- Follows WRITES
-- =========================================================

-- 1) Подписаться (idempotent). Возвращает true, если реально создали подписку.
CREATE OR REPLACE FUNCTION follow_create(
  p_follower_id uuid,
  p_following_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_inserted int;
BEGIN
  IF p_follower_id IS NULL OR p_following_id IS NULL THEN
    RAISE EXCEPTION 'follower_id and following_id are required';
  END IF;

  -- защита от self-follow (в таблице есть CHECK, но лучше читаемая ошибка)
  IF p_follower_id = p_following_id THEN
    RAISE EXCEPTION 'cannot follow yourself';
  END IF;

  -- опционально: проверим, что оба пользователя существуют (и активны)
  IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_follower_id AND u.is_active) THEN
    RAISE EXCEPTION 'follower user not found (or inactive)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_following_id AND u.is_active) THEN
    RAISE EXCEPTION 'following user not found (or inactive)';
  END IF;

  INSERT INTO user_follows(follower_id, following_id)
  VALUES (p_follower_id, p_following_id)
  ON CONFLICT (follower_id, following_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted = 1;
END $$;


-- 2) Отписаться. Возвращает true, если реально удалили подписку.
CREATE OR REPLACE FUNCTION follow_delete(
  p_follower_id uuid,
  p_following_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted int;
BEGIN
  IF p_follower_id IS NULL OR p_following_id IS NULL THEN
    RAISE EXCEPTION 'follower_id and following_id are required';
  END IF;

  DELETE FROM user_follows
  WHERE follower_id = p_follower_id
    AND following_id = p_following_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted = 1;
END $$;

COMMIT;
