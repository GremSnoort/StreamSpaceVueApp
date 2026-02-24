-- 01_enums.sql
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'video_visibility') THEN
    CREATE TYPE video_visibility AS ENUM ('public', 'private', 'protected');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'video_status') THEN
    CREATE TYPE video_status AS ENUM ('uploading', 'processing', 'ready', 'failed', 'deleted');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'folder_tree_type') THEN
    CREATE TYPE folder_tree_type AS ENUM ('library', 'favorites');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reaction_value') THEN
    CREATE TYPE reaction_value AS ENUM ('like', 'dislike');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_status') THEN
    CREATE TYPE purchase_status AS ENUM ('pending', 'paid', 'failed', 'refunded', 'canceled');
  END IF;
END $$;

COMMIT;
