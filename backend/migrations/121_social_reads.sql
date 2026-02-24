-- 121_social_reads.sql
BEGIN;

-- =========================================================
-- Social READS
-- =========================================================

-- 1) Текущая реакция пользователя на видео (если нет — NULL)
CREATE OR REPLACE FUNCTION video_get_user_reaction(
  p_video_id uuid,
  p_viewer_id uuid
)
RETURNS reaction_value
LANGUAGE sql
STABLE
AS $$
  SELECT r.value
  FROM videos v
  LEFT JOIN video_reactions r
    ON r.video_id = v.id
   AND r.user_id = p_viewer_id
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id);
$$;


-- 2) Список реакций (лайки/дизлайки) с пользователями
--    Пагинация: по времени + id (устойчиво)
CREATE OR REPLACE FUNCTION video_list_reactions(
  p_video_id uuid,
  p_viewer_id uuid,
  p_value reaction_value DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  value reaction_value,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    r.value,
    r.created_at,
    r.updated_at
  FROM videos v
  JOIN video_reactions r ON r.video_id = v.id
  JOIN users u ON u.id = r.user_id
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id)
    AND (p_value IS NULL OR r.value = p_value)
    AND (
      p_cursor_created_at IS NULL
      OR (
          r.created_at < p_cursor_created_at
          OR (
          r.created_at = p_cursor_created_at
          AND p_cursor_user_id IS NOT NULL
          AND r.user_id < p_cursor_user_id
          )
      )
    )
  ORDER BY r.created_at DESC, r.user_id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;


-- 3) Список комментариев к видео (включая автора)
--    По умолчанию скрываем удалённые (is_deleted=true)
CREATE OR REPLACE FUNCTION video_list_comments(
  p_video_id uuid,
  p_viewer_id uuid,
  p_include_deleted boolean DEFAULT false,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_comment_id uuid DEFAULT NULL
)
RETURNS TABLE (
  comment_id uuid,
  video_id uuid,
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  text text,
  is_deleted boolean,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    c.id,
    c.video_id,
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    c.text,
    c.is_deleted,
    c.created_at,
    c.updated_at
  FROM videos v
  JOIN video_comments c ON c.video_id = v.id
  JOIN users u ON u.id = c.user_id
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id)
    AND (p_include_deleted OR c.is_deleted = false)
    AND (
      p_cursor_created_at IS NULL
      OR (
        c.created_at < p_cursor_created_at
        OR (c.created_at = p_cursor_created_at AND p_cursor_comment_id IS NOT NULL AND c.id < p_cursor_comment_id)
      )
    )
  ORDER BY c.created_at DESC, c.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;


-- 4) Получить один комментарий (например, для “перейти к комменту” / модалки)
CREATE OR REPLACE FUNCTION video_get_comment(
  p_comment_id uuid,
  p_viewer_id uuid
)
RETURNS TABLE (
  comment_id uuid,
  video_id uuid,
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  text text,
  is_deleted boolean,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    c.id,
    c.video_id,
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    c.text,
    c.is_deleted,
    c.created_at,
    c.updated_at
  FROM video_comments c
  JOIN videos v ON v.id = c.video_id
  JOIN users u ON u.id = c.user_id
  WHERE c.id = p_comment_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id);
$$;


-- 5) Список просмотров (обычно админка/аналитика, поэтому по умолчанию ограничим OWNER’ом)
--    Если хочешь показывать публично — убери проверку owner_id = viewer_id.
CREATE OR REPLACE FUNCTION video_list_views(
  p_video_id uuid,
  p_viewer_id uuid,
  p_limit integer DEFAULT 50,
  p_cursor_watched_at timestamptz DEFAULT NULL,
  p_cursor_view_id uuid DEFAULT NULL
)
RETURNS TABLE (
  view_id uuid,
  watched_at timestamptz,
  viewer_id uuid,
  watch_ms integer,
  user_agent text,
  ip_address inet
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    vw.id,
    vw.watched_at,
    vw.viewer_id,
    vw.watch_ms,
    vw.user_agent,
    vw.ip_address
  FROM videos v
  JOIN video_views vw ON vw.video_id = v.id
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND v.owner_id = p_viewer_id
    AND (
      p_cursor_watched_at IS NULL
      OR (
        vw.watched_at < p_cursor_watched_at
        OR (vw.watched_at = p_cursor_watched_at AND p_cursor_view_id IS NOT NULL AND vw.id < p_cursor_view_id)
      )
    )
  ORDER BY vw.watched_at DESC, vw.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;


-- 6) “Карточка” social summary (можно дергать на страницу видео)
--    Берём денормализованные счётчики из videos + доступ
CREATE OR REPLACE FUNCTION video_get_social_summary(
  p_video_id uuid,
  p_viewer_id uuid
)
RETURNS TABLE (
  video_id uuid,
  views_count bigint,
  likes_count bigint,
  dislikes_count bigint,
  comments_count bigint,
  my_reaction reaction_value
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    v.id,
    v.views_count,
    v.likes_count,
    v.dislikes_count,
    v.comments_count,
    (
      SELECT r.value
      FROM video_reactions r
      WHERE r.video_id = v.id
        AND r.user_id = p_viewer_id
    ) AS my_reaction
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id);
$$;


COMMIT;
