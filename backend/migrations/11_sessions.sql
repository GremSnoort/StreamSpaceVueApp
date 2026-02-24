-- 11_sessions.sql
BEGIN;

CREATE TABLE IF NOT EXISTS user_sessions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  session_token_hash text NOT NULL UNIQUE, -- хеш, не raw
  user_agent         text,
  ip_address         inet,

  created_at         timestamptz NOT NULL DEFAULT now(),
  last_seen_at       timestamptz NOT NULL DEFAULT now(),
  expires_at         timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_session_expires_after_created'
      AND conrelid = 'user_sessions'::regclass
  ) THEN
    ALTER TABLE user_sessions
      ADD CONSTRAINT chk_session_expires_after_created
      CHECK (expires_at > created_at);
  END IF;
END $$;

COMMIT;
