-- 101_video_access_functions.sql
BEGIN;

-- Можно ли смотреть видео (viewer_id может быть NULL для гостя)
-- Правила:
-- 1) Владелец видит всегда (любой status, unpublished/private тоже).
-- 2) Остальные: только published_at IS NOT NULL и status='ready'
--    public -> всем
--    protected -> только подписчикам (viewer_id NOT NULL + follow)
CREATE OR REPLACE FUNCTION can_view_video(p_viewer_id uuid, p_video_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND (
        -- владелец видит всегда
        (p_viewer_id IS NOT NULL AND v.owner_id = p_viewer_id)

        -- прочие: только опубликованные и только ready
        OR (
          v.status = 'ready'
          AND v.published_at IS NOT NULL
          AND (
            v.visibility = 'public'
            OR (
              v.visibility = 'protected'
              AND p_viewer_id IS NOT NULL
              AND EXISTS (
                SELECT 1
                FROM user_follows f
                WHERE f.follower_id = p_viewer_id
                  AND f.following_id = v.owner_id
              )
            )
          )
        )
      )
  );
$$;

-- Можно ли скачивать видео (владелец или paid purchase)
CREATE OR REPLACE FUNCTION can_download_video(p_user_id uuid, p_video_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
  SELECT 1
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND (
      (p_user_id IS NOT NULL AND v.owner_id = p_user_id)
      OR EXISTS (
        SELECT 1
        FROM download_purchases p
        WHERE p.buyer_id = p_user_id
          AND p.video_id = p_video_id
          AND p.status = 'paid'
      )
    )
);
$$;

COMMIT;
