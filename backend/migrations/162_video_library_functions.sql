BEGIN;

-- =========================================================
-- Video + Library helpers
-- =========================================================

CREATE OR REPLACE FUNCTION video_create_in_library(
  p_owner_id uuid,
  p_folder_id uuid,
  p_title text,
  p_description text DEFAULT NULL,
  p_visibility video_visibility DEFAULT 'private',
  p_source_original_name text DEFAULT NULL,
  p_source_mime_type text DEFAULT NULL,
  p_source_size_bytes bigint DEFAULT NULL,
  p_source_storage_key text DEFAULT NULL,
  p_source_sha256 text DEFAULT NULL,
  p_order_index integer DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_video_id uuid;
  v_ok boolean;
BEGIN
  IF p_owner_id IS NULL THEN
    RAISE EXCEPTION 'owner_id is required';
  END IF;

  IF p_folder_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM folders f
      WHERE f.id = p_folder_id
        AND f.owner_id = p_owner_id
        AND f.tree_type = 'library'
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Library folder does not belong to user';
    END IF;
  END IF;

  v_video_id := video_create(
    p_owner_id,
    p_title,
    p_description,
    p_visibility,
    p_source_original_name,
    p_source_mime_type,
    p_source_size_bytes,
    p_source_storage_key,
    p_source_sha256
  );

  IF p_folder_id IS NOT NULL THEN
    PERFORM folder_add_video(p_folder_id, v_video_id, p_owner_id, p_order_index);
  END IF;

  RETURN v_video_id;
END $$;


CREATE OR REPLACE FUNCTION video_place_in_library_folder(
  p_owner_id uuid,
  p_video_id uuid,
  p_folder_id uuid,
  p_order_index integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_owner_id IS NULL OR p_video_id IS NULL OR p_folder_id IS NULL THEN
    RAISE EXCEPTION 'owner_id, video_id and folder_id are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND v.owner_id = p_owner_id
      AND v.status <> 'deleted'
  ) THEN
    RAISE EXCEPTION 'Video not found (or deleted)';
  END IF;

  PERFORM folder_add_video(p_folder_id, p_video_id, p_owner_id, p_order_index);
END $$;


CREATE OR REPLACE FUNCTION video_move_between_library_folders(
  p_owner_id uuid,
  p_video_id uuid,
  p_from_folder_id uuid,
  p_to_folder_id uuid,
  p_to_order_index integer DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_owner_id IS NULL OR p_video_id IS NULL OR p_from_folder_id IS NULL OR p_to_folder_id IS NULL THEN
    RAISE EXCEPTION 'owner_id, video_id, from_folder_id and to_folder_id are required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM videos v
    WHERE v.id = p_video_id
      AND v.owner_id = p_owner_id
      AND v.status <> 'deleted'
  ) THEN
    RAISE EXCEPTION 'Video not found (or deleted)';
  END IF;

  RETURN folder_move_video(
    p_from_folder_id,
    p_to_folder_id,
    p_video_id,
    p_owner_id,
    p_to_order_index
  );
END $$;

COMMIT;
