-- 111_folder_reads.sql
BEGIN;

-- =========================================================
-- Folder READS (owner-only)
-- =========================================================

-- 1) Получить папку (метаданные)
CREATE OR REPLACE FUNCTION folder_get(
  p_folder_id uuid,
  p_owner_id uuid
)
RETURNS TABLE (
  id uuid,
  owner_id uuid,
  tree_type folder_tree_type,
  parent_id uuid,
  name text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT f.id, f.owner_id, f.tree_type, f.parent_id, f.name, f.created_at, f.updated_at
  FROM folders f
  WHERE f.id = p_folder_id
    AND f.owner_id = p_owner_id;
$$;


-- 2) Список дочерних папок
--    Пагинация: (created_at, id) DESC
CREATE OR REPLACE FUNCTION folder_list_children(
  p_owner_id uuid,
  p_tree_type folder_tree_type,
  p_parent_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_folder_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  parent_id uuid,
  name text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT f.id, f.parent_id, f.name, f.created_at, f.updated_at
  FROM folders f
  WHERE f.owner_id = p_owner_id
    AND f.tree_type = p_tree_type
    AND (
      (p_parent_id IS NULL AND f.parent_id IS NULL)
      OR (p_parent_id IS NOT NULL AND f.parent_id = p_parent_id)
    )
    AND (
      p_cursor_created_at IS NULL
      OR (
          f.created_at < p_cursor_created_at
          OR (
          f.created_at = p_cursor_created_at
          AND (p_cursor_folder_id IS NULL OR f.id < p_cursor_folder_id)
          )
      )
    )
  ORDER BY f.created_at DESC, f.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;


-- 3) Список видео в папке (карточки)
--    Пагинация: (order_index NULLS LAST, added_at, video_id) для стабильности.
--    Если order_index не используется, сортировка по added_at/video_id.
CREATE OR REPLACE FUNCTION folder_list_videos(
  p_folder_id uuid,
  p_owner_id uuid,
  p_limit integer DEFAULT 50,
  p_cursor_order_index integer DEFAULT NULL,
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
  order_index integer
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_tree folder_tree_type;
  v_has_cursor boolean;
  v_cursor_key integer;
BEGIN
  SELECT f.tree_type INTO v_tree
  FROM folders f
  WHERE f.id = p_folder_id
    AND f.owner_id = p_owner_id;

  IF v_tree IS NULL THEN
    RAISE EXCEPTION 'Folder does not belong to user';
  END IF;

  -- курсор валиден либо "полностью пустой", либо "полный по tie-breaker'ам"
  v_has_cursor := (p_cursor_added_at IS NOT NULL OR p_cursor_video_id IS NOT NULL);

  IF v_has_cursor AND (p_cursor_added_at IS NULL OR p_cursor_video_id IS NULL) THEN
    RAISE EXCEPTION 'Invalid cursor: cursor_added_at and cursor_video_id must be provided together';
  END IF;

  v_cursor_key := COALESCE(p_cursor_order_index, 2147483647);

  RETURN QUERY
  SELECT
    v.id,
    v.owner_id,
    v.title,
    v.poster_key,
    v.visibility,
    v.status,
    v.published_at,
    fvi.added_at,
    fvi.order_index
  FROM folder_video_items fvi
  JOIN videos v ON v.id = fvi.video_id
  WHERE fvi.folder_id = p_folder_id
    AND v.status <> 'deleted'
    AND (
      (v_tree = 'library' AND v.owner_id = p_owner_id)
      OR
      (v_tree = 'favorites' AND can_view_video(p_owner_id, v.id))
    )
    AND (
      -- первая страница
      NOT v_has_cursor
      OR
      (
        -- keyset для ORDER BY:
        -- order_key ASC, added_at DESC, video_id DESC
        -- "после курсора" =>
        --   order_key > cursor_key
        --   OR order_key = cursor_key AND added_at < cursor_added_at
        --   OR order_key = cursor_key AND added_at = cursor_added_at AND video_id < cursor_video_id
        COALESCE(fvi.order_index, 2147483647) > v_cursor_key
        OR (
          COALESCE(fvi.order_index, 2147483647) = v_cursor_key
          AND (
            fvi.added_at < p_cursor_added_at
            OR (fvi.added_at = p_cursor_added_at AND fvi.video_id < p_cursor_video_id)
          )
        )
      )
    )
  ORDER BY
    COALESCE(fvi.order_index, 2147483647) ASC,
    fvi.added_at DESC,
    fvi.video_id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
END $$;


-- 4) Быстрый read: “избранное” без знания folder_id
--    По умолчанию ищем корневую папку favorites с именем 'favorites' (можно менять)
CREATE OR REPLACE FUNCTION favorites_list_videos(
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
  added_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  WITH fav AS (
    SELECT f.id
    FROM folders f
    WHERE f.owner_id = p_owner_id
      AND f.tree_type = 'favorites'
      AND f.parent_id IS NULL
      AND f.name = 'favorites'
    LIMIT 1
  )
  SELECT
    v.id,
    v.owner_id,
    v.title,
    v.poster_key,
    v.visibility,
    v.status,
    v.published_at,
    fvi.added_at
  FROM fav
  JOIN folder_video_items fvi ON fvi.folder_id = fav.id
  JOIN videos v ON v.id = fvi.video_id
  WHERE v.status <> 'deleted'
    AND can_view_video(p_owner_id, v.id)
    AND (
      p_cursor_added_at IS NULL
      OR (
          fvi.added_at < p_cursor_added_at
          OR (
            fvi.added_at = p_cursor_added_at
            AND p_cursor_video_id IS NOT NULL
            AND fvi.video_id < p_cursor_video_id
          )
      )
    )
  ORDER BY fvi.added_at DESC, v.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100);
$$;

COMMIT;
