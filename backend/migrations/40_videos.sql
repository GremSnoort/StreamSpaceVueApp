-- 40_videos.sql
BEGIN;

CREATE TABLE IF NOT EXISTS videos (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  title                 text NOT NULL,
  description           text,
  visibility            video_visibility NOT NULL DEFAULT 'private',
  status                video_status NOT NULL DEFAULT 'uploading',

  -- исходник
  source_original_name  text,
  source_mime_type      text,
  source_size_bytes     bigint CHECK (source_size_bytes IS NULL OR source_size_bytes >= 0),
  source_storage_key    text,  -- путь/ключ в S3/FS
  source_sha256         text,  -- опционально

  -- HLS
  hls_master_key        text,  -- путь/ключ master.m3u8
  poster_key            text,  -- путь/ключ превью
  duration_seconds      integer CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  width                 integer CHECK (width IS NULL OR width > 0),
  height                integer CHECK (height IS NULL OR height > 0),

  -- счётчики (денормализовано, обновляется приложением/джобами позже)
  views_count           bigint NOT NULL DEFAULT 0 CHECK (views_count >= 0),
  likes_count           bigint NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  dislikes_count        bigint NOT NULL DEFAULT 0 CHECK (dislikes_count >= 0),
  comments_count        bigint NOT NULL DEFAULT 0 CHECK (comments_count >= 0),

  created_at            timestamptz NOT NULL DEFAULT now(),
  published_at          timestamptz NULL,
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_title_nonempty CHECK (length(btrim(title)) > 0),
  CONSTRAINT chk_published_only_when_ready
    CHECK (published_at IS NULL OR status = 'ready'),
  CONSTRAINT chk_private_not_published
    CHECK (published_at IS NULL OR visibility <> 'private')
);

CREATE INDEX IF NOT EXISTS idx_videos_owner_created ON videos(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_visibility_status_created ON videos(visibility, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_status ON videos(status);
CREATE INDEX IF NOT EXISTS idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_published_at ON videos(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_public_ready_published
  ON videos(published_at DESC)
  WHERE visibility = 'public' AND status = 'ready' AND published_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_videos_ready_published
  ON videos(published_at DESC)
  WHERE status = 'ready' AND published_at IS NOT NULL;

COMMIT;
