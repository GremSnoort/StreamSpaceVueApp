BEGIN;

-- =========================================================
-- Stream / download read helpers
-- =========================================================

CREATE OR REPLACE FUNCTION video_get_hls_master_for_viewer(
  p_viewer_id uuid,
  p_video_id uuid
)
RETURNS TABLE (
  video_id uuid,
  hls_master_key text,
  poster_key text,
  duration_seconds integer,
  width integer,
  height integer
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    v.id,
    v.hls_master_key,
    v.poster_key,
    v.duration_seconds,
    v.width,
    v.height
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status = 'ready'
    AND v.hls_master_key IS NOT NULL
    AND can_view_video(p_viewer_id, v.id);
$$;


CREATE OR REPLACE FUNCTION video_list_hls_variants_for_viewer(
  p_viewer_id uuid,
  p_video_id uuid
)
RETURNS TABLE (
  playlist_key text,
  bandwidth integer,
  width integer,
  height integer,
  codecs text
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    hv.playlist_key,
    hv.bandwidth,
    hv.width,
    hv.height,
    hv.codecs
  FROM videos v
  JOIN video_hls_variants hv ON hv.video_id = v.id
  WHERE v.id = p_video_id
    AND v.status = 'ready'
    AND can_view_video(p_viewer_id, v.id)
  ORDER BY hv.bandwidth NULLS LAST, hv.width NULLS LAST, hv.height NULLS LAST;
$$;


CREATE OR REPLACE FUNCTION video_get_download_source_for_user(
  p_user_id uuid,
  p_video_id uuid
)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT v.source_storage_key
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status <> 'deleted'
    AND v.source_storage_key IS NOT NULL
    AND can_download_video(p_user_id, v.id);
$$;

COMMIT;
