BEGIN;

-- =========================================================
-- Favorites HELPERS (default folder + convenience writes)
-- =========================================================

CREATE OR REPLACE FUNCTION favorites_get_or_create_root(
  p_owner_id uuid,
  p_name text DEFAULT 'favorites'
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_folder_id uuid;
BEGIN
  IF p_owner_id IS NULL THEN
    RAISE EXCEPTION 'owner_id is required';
  END IF;

  IF p_name IS NULL OR length(btrim(p_name)) = 0 THEN
    RAISE EXCEPTION 'favorites root name must be non-empty';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('favorites-root:' || p_owner_id::text || ':' || lower(p_name)));

  SELECT f.id
  INTO v_folder_id
  FROM folders f
  WHERE f.owner_id = p_owner_id
    AND f.tree_type = 'favorites'
    AND f.parent_id IS NULL
    AND f.name = p_name
  ORDER BY f.created_at ASC, f.id ASC
  LIMIT 1;

  IF v_folder_id IS NULL THEN
    INSERT INTO folders(owner_id, tree_type, parent_id, name)
    VALUES (p_owner_id, 'favorites', NULL, p_name)
    RETURNING id INTO v_folder_id;
  END IF;

  RETURN v_folder_id;
END $$;


CREATE OR REPLACE FUNCTION favorites_add_video(
  p_owner_id uuid,
  p_video_id uuid,
  p_folder_id uuid DEFAULT NULL,
  p_order_index integer DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_folder_id uuid;
BEGIN
  IF p_owner_id IS NULL OR p_video_id IS NULL THEN
    RAISE EXCEPTION 'owner_id and video_id are required';
  END IF;

  IF p_folder_id IS NULL THEN
    v_folder_id := favorites_get_or_create_root(p_owner_id);
  ELSE
    SELECT f.id
    INTO v_folder_id
    FROM folders f
    WHERE f.id = p_folder_id
      AND f.owner_id = p_owner_id
      AND f.tree_type = 'favorites';

    IF v_folder_id IS NULL THEN
      RAISE EXCEPTION 'Favorites folder does not belong to user';
    END IF;
  END IF;

  PERFORM folder_add_video(v_folder_id, p_video_id, p_owner_id, p_order_index);
  RETURN v_folder_id;
END $$;


CREATE OR REPLACE FUNCTION favorites_remove_video(
  p_owner_id uuid,
  p_video_id uuid,
  p_folder_id uuid DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted int;
BEGIN
  IF p_owner_id IS NULL OR p_video_id IS NULL THEN
    RAISE EXCEPTION 'owner_id and video_id are required';
  END IF;

  IF p_folder_id IS NULL THEN
    DELETE FROM folder_video_items fvi
    USING folders f
    WHERE f.id = fvi.folder_id
      AND f.owner_id = p_owner_id
      AND f.tree_type = 'favorites'
      AND fvi.video_id = p_video_id;
  ELSE
    IF NOT EXISTS (
      SELECT 1
      FROM folders f
      WHERE f.id = p_folder_id
        AND f.owner_id = p_owner_id
        AND f.tree_type = 'favorites'
    ) THEN
      RAISE EXCEPTION 'Favorites folder does not belong to user';
    END IF;

    DELETE FROM folder_video_items fvi
    WHERE fvi.folder_id = p_folder_id
      AND fvi.video_id = p_video_id;
  END IF;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END $$;


CREATE OR REPLACE FUNCTION favorites_move_video(
  p_owner_id uuid,
  p_video_id uuid,
  p_from_folder_id uuid,
  p_to_folder_id uuid,
  p_to_order_index integer DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_cnt int;
BEGIN
  IF p_owner_id IS NULL OR p_video_id IS NULL OR p_from_folder_id IS NULL OR p_to_folder_id IS NULL THEN
    RAISE EXCEPTION 'owner_id, video_id, from_folder_id and to_folder_id are required';
  END IF;

  SELECT count(*)
  INTO v_cnt
  FROM folders f
  WHERE f.id IN (p_from_folder_id, p_to_folder_id)
    AND f.owner_id = p_owner_id
    AND f.tree_type = 'favorites';

  IF v_cnt <> 2 THEN
    RAISE EXCEPTION 'Both folders must belong to favorites tree of the user';
  END IF;

  RETURN folder_move_video(
    p_from_folder_id,
    p_to_folder_id,
    p_video_id,
    p_owner_id,
    p_to_order_index
  );
END $$;


CREATE OR REPLACE FUNCTION favorites_is_video_saved(
  p_owner_id uuid,
  p_video_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM folder_video_items fvi
    JOIN folders f ON f.id = fvi.folder_id
    WHERE f.owner_id = p_owner_id
      AND f.tree_type = 'favorites'
      AND fvi.video_id = p_video_id
  );
$$;

COMMIT;
