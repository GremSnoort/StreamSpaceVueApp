-- 120_social_functions.sql
BEGIN;

-- Upsert реакции + пересчёт денормализованных счётчиков (лайки/дизлайки)
-- FIX(B): check access + forbid deleted videos
CREATE OR REPLACE FUNCTION video_set_reaction(
  p_video_id uuid,
  p_user_id uuid,
  p_value reaction_value
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ok boolean;
  v_likes bigint;
  v_dislikes bigint;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND v.status <> 'deleted'
      AND can_view_video(p_user_id, v.id)
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'No access to video (or video deleted)';
  END IF;

  INSERT INTO video_reactions(video_id, user_id, value)
  VALUES (p_video_id, p_user_id, p_value)
  ON CONFLICT (video_id, user_id)
  DO UPDATE SET value = EXCLUDED.value, updated_at = now();

  SELECT
    count(*) FILTER (WHERE value = 'like'),
    count(*) FILTER (WHERE value = 'dislike')
  INTO v_likes, v_dislikes
  FROM video_reactions
  WHERE video_id = p_video_id;

  UPDATE videos
  SET likes_count = v_likes,
      dislikes_count = v_dislikes,
      updated_at = now()
  WHERE id = p_video_id;
END $$;

-- Добавить комментарий + инкремент comments_count
-- FIX(B): check access + forbid deleted videos
CREATE OR REPLACE FUNCTION video_add_comment(
  p_video_id uuid,
  p_user_id uuid,
  p_text text
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
  v_ok boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  IF length(btrim(p_text)) = 0 THEN
    RAISE EXCEPTION 'Comment text must be non-empty';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND v.status <> 'deleted'
      AND can_view_video(p_user_id, v.id)
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'No access to video (or video deleted)';
  END IF;

  INSERT INTO video_comments(video_id, user_id, text)
  VALUES (p_video_id, p_user_id, p_text)
  RETURNING id INTO v_id;

  UPDATE videos
  SET comments_count = comments_count + 1,
      updated_at = now()
  WHERE id = p_video_id;

  RETURN v_id;
END $$;

-- Мягкое удаление комментария (только автор)
-- (доступ к видео не обязателен: это "own write" по комменту)
-- но не трогаем counters у deleted-видео
CREATE OR REPLACE FUNCTION video_delete_comment(
  p_comment_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_video_id uuid;
  v_updated integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;

  SELECT c.video_id INTO v_video_id
  FROM video_comments c
  WHERE c.id = p_comment_id;

  IF v_video_id IS NULL THEN
    RETURN false;
  END IF;

  UPDATE video_comments
  SET is_deleted = true,
      updated_at = now()
  WHERE id = p_comment_id
    AND user_id = p_user_id
    AND is_deleted = false;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 1 THEN
    UPDATE videos
    SET comments_count = GREATEST(comments_count - 1, 0),
        updated_at = now()
    WHERE id = v_video_id
      AND status <> 'deleted';

    RETURN true;
  END IF;

  RETURN false;
END $$;

-- Записать просмотр + инкремент views_count
-- FIX(B): check access + forbid deleted videos (viewer may be NULL)
CREATE OR REPLACE FUNCTION video_record_view(
  p_video_id uuid,
  p_viewer_id uuid,
  p_watch_ms integer,
  p_user_agent text,
  p_ip inet
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND v.status <> 'deleted'
      AND can_view_video(p_viewer_id, v.id)
  ) INTO v_ok;

  IF NOT v_ok THEN
    RAISE EXCEPTION 'No access to video (or video deleted)';
  END IF;

  INSERT INTO video_views(video_id, viewer_id, watch_ms, user_agent, ip_address)
  VALUES (p_video_id, p_viewer_id, p_watch_ms, p_user_agent, p_ip);

  UPDATE videos
  SET views_count = views_count + 1
  WHERE id = p_video_id;
END $$;

COMMIT;
