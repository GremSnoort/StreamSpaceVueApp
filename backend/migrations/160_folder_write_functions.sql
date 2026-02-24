BEGIN;

-- =========================================================
-- Folder WRITES
-- =========================================================

CREATE OR REPLACE FUNCTION folder_rename(
  p_folder_id uuid,
  p_owner_id uuid,
  p_new_name text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
BEGIN
  IF p_folder_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'folder_id and owner_id are required';
  END IF;

  IF p_new_name IS NULL OR length(btrim(p_new_name)) = 0 THEN
    RAISE EXCEPTION 'Folder name must be non-empty';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM folders f
    WHERE f.id = p_folder_id
      AND f.owner_id = p_owner_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    RETURN false;
  END IF;

  UPDATE folders f
  SET name = p_new_name,
      updated_at = now()
  WHERE f.id = p_folder_id
    AND f.owner_id = p_owner_id;

  RETURN true;
END $$;


CREATE OR REPLACE FUNCTION folder_move(
  p_folder_id uuid,
  p_owner_id uuid,
  p_new_parent_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_tree_type folder_tree_type;
  v_current_parent_id uuid;
  v_parent_owner_id uuid;
  v_parent_tree_type folder_tree_type;
  v_updated int;
BEGIN
  IF p_folder_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'folder_id and owner_id are required';
  END IF;

  SELECT f.tree_type, f.parent_id
  INTO v_tree_type, v_current_parent_id
  FROM folders f
  WHERE f.id = p_folder_id
    AND f.owner_id = p_owner_id;

  IF v_tree_type IS NULL THEN
    RETURN false;
  END IF;

  IF p_new_parent_id = p_folder_id THEN
    RAISE EXCEPTION 'Folder cannot be moved into itself';
  END IF;

  IF p_new_parent_id IS NULL THEN
    IF v_current_parent_id IS NULL THEN
      RETURN true;
    END IF;

    UPDATE folders
    SET parent_id = NULL,
        updated_at = now()
    WHERE id = p_folder_id
      AND owner_id = p_owner_id;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated = 1;
  END IF;

  SELECT f.owner_id, f.tree_type
  INTO v_parent_owner_id, v_parent_tree_type
  FROM folders f
  WHERE f.id = p_new_parent_id;

  IF v_parent_owner_id IS NULL THEN
    RAISE EXCEPTION 'Parent folder not found';
  END IF;

  IF v_parent_owner_id <> p_owner_id OR v_parent_tree_type <> v_tree_type THEN
    RAISE EXCEPTION 'Invalid parent folder (owner/tree mismatch)';
  END IF;

  IF EXISTS (
    WITH RECURSIVE subtree AS (
      SELECT id
      FROM folders
      WHERE parent_id = p_folder_id

      UNION ALL

      SELECT f.id
      FROM folders f
      JOIN subtree s ON s.id = f.parent_id
    )
    SELECT 1
    FROM subtree
    WHERE id = p_new_parent_id
  ) THEN
    RAISE EXCEPTION 'Folder cannot be moved into its own subtree';
  END IF;

  IF v_current_parent_id = p_new_parent_id THEN
    RETURN true;
  END IF;

  UPDATE folders
  SET parent_id = p_new_parent_id,
      updated_at = now()
  WHERE id = p_folder_id
    AND owner_id = p_owner_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


CREATE OR REPLACE FUNCTION folder_delete(
  p_folder_id uuid,
  p_owner_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted int;
BEGIN
  IF p_folder_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'folder_id and owner_id are required';
  END IF;

  DELETE FROM folders f
  WHERE f.id = p_folder_id
    AND f.owner_id = p_owner_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted = 1;
END $$;


CREATE OR REPLACE FUNCTION folder_remove_video(
  p_folder_id uuid,
  p_video_id uuid,
  p_owner_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
  v_deleted int;
BEGIN
  IF p_folder_id IS NULL OR p_video_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'folder_id, video_id and owner_id are required';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM folders f
    WHERE f.id = p_folder_id
      AND f.owner_id = p_owner_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    RAISE EXCEPTION 'Folder does not belong to user';
  END IF;

  DELETE FROM folder_video_items fvi
  WHERE fvi.folder_id = p_folder_id
    AND fvi.video_id = p_video_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted = 1;
END $$;


CREATE OR REPLACE FUNCTION folder_set_video_order(
  p_folder_id uuid,
  p_video_id uuid,
  p_owner_id uuid,
  p_order_index integer
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_exists boolean;
  v_updated int;
BEGIN
  IF p_folder_id IS NULL OR p_video_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'folder_id, video_id and owner_id are required';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM folders f
    WHERE f.id = p_folder_id
      AND f.owner_id = p_owner_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    RAISE EXCEPTION 'Folder does not belong to user';
  END IF;

  UPDATE folder_video_items fvi
  SET order_index = p_order_index,
      added_at = now(),
      added_by = p_owner_id
  WHERE fvi.folder_id = p_folder_id
    AND fvi.video_id = p_video_id;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


CREATE OR REPLACE FUNCTION folder_move_video(
  p_from_folder_id uuid,
  p_to_folder_id uuid,
  p_video_id uuid,
  p_owner_id uuid,
  p_to_order_index integer DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_from_tree folder_tree_type;
  v_to_tree folder_tree_type;
  v_deleted int;
BEGIN
  IF p_from_folder_id IS NULL OR p_to_folder_id IS NULL OR p_video_id IS NULL OR p_owner_id IS NULL THEN
    RAISE EXCEPTION 'from_folder_id, to_folder_id, video_id and owner_id are required';
  END IF;

  SELECT f.tree_type
  INTO v_from_tree
  FROM folders f
  WHERE f.id = p_from_folder_id
    AND f.owner_id = p_owner_id;

  IF v_from_tree IS NULL THEN
    RAISE EXCEPTION 'Source folder does not belong to user';
  END IF;

  SELECT f.tree_type
  INTO v_to_tree
  FROM folders f
  WHERE f.id = p_to_folder_id
    AND f.owner_id = p_owner_id;

  IF v_to_tree IS NULL THEN
    RAISE EXCEPTION 'Destination folder does not belong to user';
  END IF;

  IF v_from_tree <> v_to_tree THEN
    RAISE EXCEPTION 'Cannot move video across different folder trees';
  END IF;

  IF p_from_folder_id = p_to_folder_id THEN
    RETURN folder_set_video_order(p_to_folder_id, p_video_id, p_owner_id, p_to_order_index);
  END IF;

  DELETE FROM folder_video_items fvi
  WHERE fvi.folder_id = p_from_folder_id
    AND fvi.video_id = p_video_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted = 0 THEN
    RETURN false;
  END IF;

  PERFORM folder_add_video(p_to_folder_id, p_video_id, p_owner_id, p_to_order_index);
  RETURN true;
END $$;

COMMIT;
