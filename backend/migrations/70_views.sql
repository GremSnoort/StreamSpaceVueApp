-- 70_views.sql
BEGIN;

CREATE TABLE IF NOT EXISTS video_views (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id     uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  viewer_id    uuid NULL REFERENCES users(id) ON DELETE SET NULL, -- гость = NULL

  watched_at   timestamptz NOT NULL DEFAULT now(),
  watch_ms     integer CHECK (watch_ms IS NULL OR watch_ms >= 0),

  user_agent   text,
  ip_address   inet
);

CREATE INDEX IF NOT EXISTS idx_video_views_video_time ON video_views(video_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_views_viewer_time ON video_views(viewer_id, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_views_time_video ON video_views(watched_at DESC, video_id);

COMMIT;
