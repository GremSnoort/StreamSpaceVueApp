-- 50_reactions.sql
BEGIN;

CREATE TABLE IF NOT EXISTS video_reactions (
  video_id     uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  value        reaction_value NOT NULL, -- like | dislike
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (video_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_video_reactions_user ON video_reactions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_reactions_video_value ON video_reactions(video_id, value);

COMMIT;
