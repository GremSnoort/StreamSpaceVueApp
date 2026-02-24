-- 150_feed_functions.sql
BEGIN;

-- Записать событие публикации
CREATE OR REPLACE FUNCTION feed_video_published(p_actor_user_id uuid, p_video_id uuid)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO feed_events(actor_user_id, video_id, event_type)
  VALUES (p_actor_user_id, p_video_id, 'video_published')
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

-- Лента по подпискам: опубликованные видео авторов, на которых подписан пользователь
CREATE OR REPLACE FUNCTION feed_following(
  p_user_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  video_id uuid,
  owner_id uuid,
  title text,
  poster_key text,
  published_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT v.id, v.owner_id, v.title, v.poster_key, v.published_at
  FROM user_follows f
  JOIN videos v ON v.owner_id = f.following_id
  WHERE f.follower_id = p_user_id
    AND v.status = 'ready'
    AND v.published_at IS NOT NULL
    AND v.visibility IN ('public','protected')
  ORDER BY v.published_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

COMMIT;
