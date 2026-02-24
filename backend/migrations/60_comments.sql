-- 60_comments.sql
BEGIN;

CREATE TABLE IF NOT EXISTS video_comments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id     uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  text         text NOT NULL,
  is_deleted   boolean NOT NULL DEFAULT false,

  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_comment_text_nonempty CHECK (length(btrim(text)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_video_comments_video_created ON video_comments(video_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_comments_user_created ON video_comments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_comments_video_created_not_deleted
  ON video_comments(video_id, created_at DESC)
  WHERE is_deleted = false;

COMMIT;
