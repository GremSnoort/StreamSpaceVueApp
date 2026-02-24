BEGIN;

-- =========================================================
-- Hot feed
-- =========================================================

CREATE OR REPLACE FUNCTION feed_hot(
  p_viewer_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_window interval DEFAULT interval '48 hours'
)
RETURNS TABLE (
  video_id uuid,
  owner_id uuid,
  title text,
  poster_key text,
  published_at timestamptz,
  score numeric,
  views_window bigint,
  likes_window bigint,
  comments_window bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH cfg AS (
    SELECT now() AS now_ts,
           now() - p_window AS window_start,
           GREATEST(1::numeric, (EXTRACT(EPOCH FROM p_window) / 3600.0)::numeric) AS window_hours
  ),
  visible AS (
    SELECT v.id, v.owner_id, v.title, v.poster_key, v.published_at, cfg.now_ts
    FROM videos v
    CROSS JOIN cfg
    WHERE v.status = 'ready'
      AND v.published_at IS NOT NULL
      AND can_view_video(p_viewer_id, v.id)
  ),
  vv AS (
    SELECT vw.video_id, count(*)::bigint AS cnt
    FROM video_views vw
    CROSS JOIN cfg
    WHERE vw.watched_at >= cfg.window_start
    GROUP BY vw.video_id
  ),
  vr AS (
    SELECT r.video_id,
           count(*) FILTER (WHERE r.value = 'like')::bigint AS likes_cnt
    FROM video_reactions r
    CROSS JOIN cfg
    WHERE r.updated_at >= cfg.window_start
    GROUP BY r.video_id
  ),
  vc AS (
    SELECT c.video_id, count(*)::bigint AS cnt
    FROM video_comments c
    CROSS JOIN cfg
    WHERE c.created_at >= cfg.window_start
      AND c.is_deleted = false
    GROUP BY c.video_id
  )
  SELECT
    v.id,
    v.owner_id,
    v.title,
    v.poster_key,
    v.published_at,
    (
      COALESCE(vv.cnt, 0)::numeric * 1.0
      + COALESCE(vr.likes_cnt, 0)::numeric * 3.0
      + COALESCE(vc.cnt, 0)::numeric * 4.0
      + GREATEST(
          0::numeric,
          cfg.window_hours - (EXTRACT(EPOCH FROM (v.now_ts - v.published_at)) / 3600.0)::numeric
        ) * 0.1
    ) AS score,
    COALESCE(vv.cnt, 0) AS views_window,
    COALESCE(vr.likes_cnt, 0) AS likes_window,
    COALESCE(vc.cnt, 0) AS comments_window
  FROM visible v
  CROSS JOIN cfg
  LEFT JOIN vv ON vv.video_id = v.id
  LEFT JOIN vr ON vr.video_id = v.id
  LEFT JOIN vc ON vc.video_id = v.id
  ORDER BY score DESC, v.published_at DESC, v.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100)
  OFFSET GREATEST(p_offset, 0);
$$;

COMMIT;
