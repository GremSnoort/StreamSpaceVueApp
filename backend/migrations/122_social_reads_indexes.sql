BEGIN;

CREATE INDEX IF NOT EXISTS idx_video_reactions_video_created_user
  ON video_reactions(video_id, created_at DESC, user_id DESC);

CREATE INDEX IF NOT EXISTS idx_video_comments_video_created_id
  ON video_comments(video_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_video_comments_video_created_id_not_deleted
  ON video_comments(video_id, created_at DESC, id DESC)
  WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_video_views_video_time_id
  ON video_views(video_id, watched_at DESC, id DESC);

COMMIT;
