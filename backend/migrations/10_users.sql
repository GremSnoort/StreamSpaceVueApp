-- 10_users.sql
BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email             citext NOT NULL UNIQUE,
  username          citext NOT NULL UNIQUE,
  password_hash     text, -- если сессионная auth через backend; может быть NULL при OAuth
  display_name      text,
  avatar_url        text,
  bio               text,

  is_active         boolean NOT NULL DEFAULT true,

  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Часто ищут по username (если будет публичный профиль)
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

COMMIT;
