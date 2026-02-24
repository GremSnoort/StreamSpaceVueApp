-- 90_feed.sql
BEGIN;

-- События для ленты (например: "опубликовано видео")
CREATE TABLE IF NOT EXISTS feed_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- кто сделал
  video_id      uuid NULL REFERENCES videos(id) ON DELETE CASCADE,

  event_type    text NOT NULL, -- 'video_published', 'video_updated', ...
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_events_created ON feed_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_events_actor_created ON feed_events(actor_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_events_video_created ON feed_events(video_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_events_type_created
  ON feed_events(event_type, created_at DESC);

COMMIT;
