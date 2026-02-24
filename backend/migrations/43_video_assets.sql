-- 43_video_assets.sql
BEGIN;

CREATE TABLE IF NOT EXISTS video_hls_variants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id         uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,

  bandwidth        integer NULL CHECK (bandwidth IS NULL OR bandwidth > 0), -- битрейт из плейлиста
  width            integer NULL CHECK (width IS NULL OR width > 0),
  height           integer NULL CHECK (height IS NULL OR height > 0),
  codecs           text,

  playlist_key     text NOT NULL, -- путь/ключ к variant playlist (.m3u8)
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_video_hls_variants_video ON video_hls_variants(video_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_video_hls_variants_playlist
  ON video_hls_variants(video_id, playlist_key);
CREATE UNIQUE INDEX IF NOT EXISTS uq_video_hls_variants_dims_bw
  ON video_hls_variants(video_id, width, height, bandwidth)
  WHERE width IS NOT NULL AND height IS NOT NULL AND bandwidth IS NOT NULL;

COMMIT;
