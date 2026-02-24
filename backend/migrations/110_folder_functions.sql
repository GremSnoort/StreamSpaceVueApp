-- 110_folder_functions.sql
BEGIN;

-- Создать папку с проверкой: parent принадлежит тому же owner и tree_type
CREATE OR REPLACE FUNCTION folder_create(
  p_owner_id uuid,
  p_tree_type folder_tree_type,
  p_parent_id uuid,
  p_name text
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
  v_ok boolean;
BEGIN
  IF length(btrim(p_name)) = 0 THEN
    RAISE EXCEPTION 'Folder name must be non-empty';
  END IF;

  IF p_parent_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM folders f
      WHERE f.id = p_parent_id
        AND f.owner_id = p_owner_id
        AND f.tree_type = p_tree_type
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Invalid parent folder (owner/tree mismatch)';
    END IF;
  END IF;

  INSERT INTO folders(owner_id, tree_type, parent_id, name)
  VALUES (p_owner_id, p_tree_type, p_parent_id, p_name)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

-- Добавить видео в папку:
-- - папка должна принадлежать added_by
-- - если tree_type='library' -> видео должно принадлежать added_by и быть не deleted
-- - если tree_type='favorites' -> видео может быть любым, но НЕ deleted
CREATE OR REPLACE FUNCTION folder_add_video(
  p_folder_id uuid,
  p_video_id uuid,
  p_added_by uuid,
  p_order_index integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_tree folder_tree_type;
  v_ok boolean;
BEGIN
  -- папка принадлежит пользователю + узнаем тип дерева
  SELECT f.tree_type
  INTO v_tree
  FROM folders f
  WHERE f.id = p_folder_id
    AND f.owner_id = p_added_by;

  IF v_tree IS NULL THEN
    RAISE EXCEPTION 'Folder does not belong to user';
  END IF;

  IF v_tree = 'library' THEN
    SELECT EXISTS (
      SELECT 1
      FROM videos v
      WHERE v.id = p_video_id
        AND v.owner_id = p_added_by
        AND v.status <> 'deleted'
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Library folder can contain only non-deleted owner videos';
    END IF;

  ELSE
    SELECT EXISTS (
      SELECT 1
      FROM videos v
      WHERE v.id = p_video_id
        AND v.status <> 'deleted'
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Video not found (or deleted)';
    END IF;
  END IF;

  INSERT INTO folder_video_items(folder_id, video_id, added_by, order_index)
  VALUES (p_folder_id, p_video_id, p_added_by, p_order_index)
  ON CONFLICT (folder_id, video_id)
  DO UPDATE SET
    order_index = EXCLUDED.order_index,
    added_at = now(),
    added_by = EXCLUDED.added_by;
END $$;

COMMIT;
