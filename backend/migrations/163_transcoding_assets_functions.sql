BEGIN;

-- =========================================================
-- Transcoding assets / metadata writes
-- =========================================================

CREATE OR REPLACE FUNCTION transcode_set_video_media_info(
  p_video_id uuid,
  p_duration_seconds integer,
  p_width integer,
  p_height integer,
  p_source_size_bytes bigint DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
BEGIN
  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  UPDATE videos v
  SET duration_seconds = p_duration_seconds,
      width = p_width,
      height = p_height,
      source_size_bytes = COALESCE(p_source_size_bytes, v.source_size_bytes),
      updated_at = now()
  WHERE v.id = p_video_id
    AND v.status <> 'deleted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;


CREATE OR REPLACE FUNCTION transcode_add_hls_variant(
  p_video_id uuid,
  p_playlist_key text,
  p_bandwidth integer DEFAULT NULL,
  p_width integer DEFAULT NULL,
  p_height integer DEFAULT NULL,
  p_codecs text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  IF p_playlist_key IS NULL OR length(btrim(p_playlist_key)) = 0 THEN
    RAISE EXCEPTION 'playlist_key is required';
  END IF;

  INSERT INTO video_hls_variants(video_id, playlist_key, bandwidth, width, height, codecs)
  VALUES (p_video_id, p_playlist_key, p_bandwidth, p_width, p_height, p_codecs)
  ON CONFLICT (video_id, playlist_key)
  DO UPDATE SET
    bandwidth = EXCLUDED.bandwidth,
    width = EXCLUDED.width,
    height = EXCLUDED.height,
    codecs = EXCLUDED.codecs
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;


CREATE OR REPLACE FUNCTION transcode_replace_hls_variants(
  p_video_id uuid,
  p_variants jsonb
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_inserted int;
BEGIN
  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  IF p_variants IS NULL OR jsonb_typeof(p_variants) <> 'array' THEN
    RAISE EXCEPTION 'variants must be a JSON array';
  END IF;

  DELETE FROM video_hls_variants
  WHERE video_id = p_video_id;

  INSERT INTO video_hls_variants(video_id, playlist_key, bandwidth, width, height, codecs)
  SELECT
    p_video_id,
    x.playlist_key,
    x.bandwidth,
    x.width,
    x.height,
    x.codecs
  FROM jsonb_to_recordset(p_variants) AS x(
    playlist_key text,
    bandwidth integer,
    width integer,
    height integer,
    codecs text
  )
  WHERE x.playlist_key IS NOT NULL
    AND length(btrim(x.playlist_key)) > 0;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END $$;


CREATE OR REPLACE FUNCTION transcode_finalize_video(
  p_video_id uuid,
  p_hls_master_key text,
  p_poster_key text,
  p_duration_seconds integer DEFAULT NULL,
  p_width integer DEFAULT NULL,
  p_height integer DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
BEGIN
  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  IF p_hls_master_key IS NULL OR length(btrim(p_hls_master_key)) = 0 THEN
    RAISE EXCEPTION 'hls_master_key is required';
  END IF;

  UPDATE videos v
  SET status = 'ready',
      hls_master_key = p_hls_master_key,
      poster_key = COALESCE(p_poster_key, v.poster_key),
      duration_seconds = COALESCE(p_duration_seconds, v.duration_seconds),
      width = COALESCE(p_width, v.width),
      height = COALESCE(p_height, v.height),
      updated_at = now()
  WHERE v.id = p_video_id
    AND v.status <> 'deleted';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;

COMMIT;
