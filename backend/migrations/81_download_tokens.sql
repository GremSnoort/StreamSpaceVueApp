-- 81_download_tokens.sql
BEGIN;

CREATE TABLE IF NOT EXISTS video_download_tokens (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id       uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,

  owner_user_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- owner: NULL allowed; buyer: must be NOT NULL (enforced in function)
  purchase_id    uuid NULL REFERENCES download_purchases(id) ON DELETE RESTRICT,

  token_hash     text NOT NULL UNIQUE,
  expires_at     timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  used_at        timestamptz NULL,
  revoked_at     timestamptz NULL
);

-- 2) гарантируем, что purchase_id nullable на уже существующей БД (БЕЗОПАСНО / ИДЕМПОТЕНТНО)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_attribute a
    WHERE a.attrelid = 'video_download_tokens'::regclass
      AND a.attname = 'purchase_id'
      AND a.attnotnull = true
  ) THEN
    ALTER TABLE video_download_tokens
      ALTER COLUMN purchase_id DROP NOT NULL;
  END IF;
END $$;

-- 3) один "активный" токен на purchase_id (owner-токены не участвуют, т.к. purchase_id IS NOT NULL)
DROP INDEX IF EXISTS uq_active_download_token_per_purchase;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_download_token_per_purchase
  ON video_download_tokens(purchase_id)
  WHERE purchase_id IS NOT NULL
    AND used_at IS NULL
    AND revoked_at IS NULL;

-- Индексы
CREATE INDEX IF NOT EXISTS idx_video_download_tokens_video
  ON video_download_tokens(video_id, expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_video_download_tokens_owner
  ON video_download_tokens(owner_user_id, expires_at DESC);

COMMIT;
