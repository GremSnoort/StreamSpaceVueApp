-- 102_video_core_functions.sql
BEGIN;

-- Создать видео (черновик под загрузку)
CREATE OR REPLACE FUNCTION video_create(
  p_owner_id uuid,
  p_title text,
  p_description text DEFAULT NULL,
  p_visibility video_visibility DEFAULT 'private',
  p_source_original_name text DEFAULT NULL,
  p_source_mime_type text DEFAULT NULL,
  p_source_size_bytes bigint DEFAULT NULL,
  p_source_storage_key text DEFAULT NULL,
  p_source_sha256 text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_owner_id IS NULL THEN
    RAISE EXCEPTION 'owner_id is required';
  END IF;

  IF length(btrim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title must be non-empty';
  END IF;

  INSERT INTO videos(
    owner_id,
    title, description, visibility,
    status,
    source_original_name, source_mime_type, source_size_bytes, source_storage_key, source_sha256
  )
  VALUES (
    p_owner_id,
    p_title, p_description, p_visibility,
    'uploading',
    p_source_original_name, p_source_mime_type, p_source_size_bytes, p_source_storage_key, p_source_sha256
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;


-- Обновить метаданные (title/description/visibility)
CREATE OR REPLACE FUNCTION video_update_metadata(
  p_owner_id uuid,
  p_video_id uuid,
  p_title text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_visibility video_visibility DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
  v_new_visibility video_visibility;
BEGIN
  IF p_owner_id IS NULL THEN
    RAISE EXCEPTION 'owner_id is required';
  END IF;

  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  IF p_title IS NOT NULL AND length(btrim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title must be non-empty';
  END IF;

  -- вычислим итоговую visibility, чтобы корректно снять published_at при private
  SELECT COALESCE(p_visibility, v.visibility)
  INTO v_new_visibility
  FROM videos v
  WHERE v.id = p_video_id AND v.owner_id = p_owner_id;

  IF v_new_visibility IS NULL THEN
    RETURN false;
  END IF;

  UPDATE videos v
  SET
    title = COALESCE(p_title, v.title),
    description = COALESCE(p_description, v.description),
    visibility = COALESCE(p_visibility, v.visibility),
    published_at = CASE
      WHEN COALESCE(p_visibility, v.visibility) = 'private' THEN NULL
      ELSE v.published_at
    END,
    updated_at = now()
  WHERE v.id = p_video_id
    AND v.owner_id = p_owner_id
    AND v.status <> 'deleted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


-- Опубликовать видео
CREATE OR REPLACE FUNCTION video_publish(
  p_owner_id uuid,
  p_video_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_visibility video_visibility;
  v_status video_status;
  v_updated int;
BEGIN
  SELECT v.visibility, v.status
  INTO v_visibility, v_status
  FROM videos v
  WHERE v.id = p_video_id
    AND v.owner_id = p_owner_id
    AND v.status <> 'deleted';

  IF v_status IS NULL THEN
    RETURN false;
  END IF;

  IF v_status <> 'ready' THEN
    RAISE EXCEPTION 'Video must be ready to publish';
  END IF;

  IF v_visibility = 'private' THEN
    RAISE EXCEPTION 'Private video cannot be published';
  END IF;

  UPDATE videos
  SET published_at = now(),
      updated_at = now()
  WHERE id = p_video_id
    AND owner_id = p_owner_id
    AND published_at IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  -- пишем событие, только если реально впервые опубликовали
  IF v_updated = 1 THEN
    INSERT INTO feed_events(actor_user_id, video_id, event_type)
    VALUES (p_owner_id, p_video_id, 'video_published');
  END IF;

  RETURN v_updated = 1;
END $$;


-- Снять с публикации
CREATE OR REPLACE FUNCTION video_unpublish(
  p_owner_id uuid,
  p_video_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
BEGIN
  UPDATE videos
  SET published_at = NULL,
      updated_at = now()
  WHERE id = p_video_id
    AND owner_id = p_owner_id
    AND status <> 'deleted'
    AND published_at IS NOT NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


-- Мягкое удаление видео (status=deleted)
CREATE OR REPLACE FUNCTION video_delete(
  p_owner_id uuid,
  p_video_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
BEGIN
  UPDATE videos
  SET status = 'deleted',
      published_at = NULL,
      updated_at = now()
  WHERE id = p_video_id
    AND owner_id = p_owner_id
    AND status <> 'deleted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


-- Получить видео с проверкой can_view_video (viewer_id может быть NULL)
CREATE OR REPLACE FUNCTION video_get(
  p_viewer_id uuid,
  p_video_id uuid
)
RETURNS TABLE (
  id uuid,
  owner_id uuid,
  title text,
  description text,
  visibility video_visibility,
  status video_status,
  source_original_name text,
  source_mime_type text,
  source_size_bytes bigint,
  source_storage_key text,
  source_sha256 text,
  hls_master_key text,
  poster_key text,
  duration_seconds integer,
  width integer,
  height integer,
  views_count bigint,
  likes_count bigint,
  dislikes_count bigint,
  comments_count bigint,
  created_at timestamptz,
  published_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    v.id, v.owner_id, v.title, v.description, v.visibility, v.status,
    v.source_original_name, v.source_mime_type, v.source_size_bytes, v.source_storage_key, v.source_sha256,
    v.hls_master_key, v.poster_key, v.duration_seconds, v.width, v.height,
    v.views_count, v.likes_count, v.dislikes_count, v.comments_count,
    v.created_at, v.published_at, v.updated_at
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND can_view_video(p_viewer_id, v.id);
$$;


-- Публичная лента (public + ready + published)
CREATE OR REPLACE FUNCTION video_list_public_feed(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  owner_id uuid,
  title text,
  poster_key text,
  published_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT v.id, v.owner_id, v.title, v.poster_key, v.published_at
  FROM videos v
  WHERE v.status = 'ready'
    AND v.visibility = 'public'
    AND v.published_at IS NOT NULL
  ORDER BY v.published_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;


-- Все видео владельца (включая unpublished и любые статусы кроме deleted)
CREATE OR REPLACE FUNCTION video_list_owner(
  p_owner_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  title text,
  visibility video_visibility,
  status video_status,
  poster_key text,
  created_at timestamptz,
  published_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT v.id, v.title, v.visibility, v.status, v.poster_key, v.created_at, v.published_at, v.updated_at
  FROM videos v
  WHERE v.owner_id = p_owner_id
    AND v.status <> 'deleted'
  ORDER BY v.created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;


-- Видео автора, которые может видеть viewer (viewer может быть NULL)
CREATE OR REPLACE FUNCTION video_list_user_visible(
  p_viewer_id uuid,
  p_owner_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  title text,
  poster_key text,
  published_at timestamptz,
  visibility video_visibility
)
LANGUAGE sql
STABLE
AS $$
  SELECT v.id, v.title, v.poster_key, v.published_at, v.visibility
  FROM videos v
  WHERE v.owner_id = p_owner_id
    AND v.status <> 'deleted'
    AND (
      -- owner sees all (including unpublished/private, any status кроме deleted)
      (p_viewer_id IS NOT NULL AND p_viewer_id = p_owner_id)

      OR
      (
        -- others: only published + ready + access rules
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
                AND f.following_id = p_owner_id
            )
          )
        )
      )
    )
  ORDER BY
    -- owner: newest first by created; others: by published
    CASE WHEN (p_viewer_id IS NOT NULL AND p_viewer_id = p_owner_id)
      THEN v.created_at
      ELSE v.published_at
    END DESC
  LIMIT p_limit OFFSET p_offset;
$$;

COMMIT;
