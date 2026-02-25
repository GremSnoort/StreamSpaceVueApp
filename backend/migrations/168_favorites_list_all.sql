BEGIN;

-- =========================================================
-- Favorites read: aggregated across entire favorites tree
-- =========================================================

CREATE OR REPLACE FUNCTION favorites_list_all(
  p_owner_id uuid,
  p_limit integer DEFAULT 50,
  p_cursor_added_at timestamptz DEFAULT NULL,
  p_cursor_video_id uuid DEFAULT NULL
)
RETURNS TABLE (
  video_id uuid,
  owner_id uuid,
  title text,
  poster_key text,
  visibility video_visibility,
  status video_status,
  published_at timestamptz,
  added_at timestamptz,
  folders_count bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH fav_items AS (
    SELECT
      fvi.video_id,
      max(fvi.added_at) AS added_at,
      count(*)::bigint AS folders_count
    FROM folder_video_items fvi
    JOIN folders f ON f.id = fvi.folder_id
    WHERE f.owner_id = p_owner_id
      AND f.tree_type = 'favorites'
    GROUP BY fvi.video_id
  )
  SELECT
    v.id,
    v.owner_id,
    v.title,
    v.poster_key,
    v.visibility,
    v.status,
    v.published_at,
    fi.added_at,
    fi.folders_count
  FROM fav_items fi
  JOIN videos v ON v.id = fi.video_id
  WHERE v.status <> 'deleted'
    AND can_view_video(p_owner_id, v.id)
    AND (
      p_cursor_added_at IS NULL
      OR (
        fi.added_at < p_cursor_added_at
        OR (
          fi.added_at = p_cursor_added_at
          AND p_cursor_video_id IS NOT NULL
          AND v.id < p_cursor_video_id
        )
      )
    )
  ORDER BY fi.added_at DESC, v.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;

COMMIT;
