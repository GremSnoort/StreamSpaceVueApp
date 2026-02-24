BEGIN;

-- =========================================================
-- Social write extras (reaction delete, comment edit)
-- =========================================================

CREATE OR REPLACE FUNCTION video_remove_reaction(
  p_video_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted int;
  v_likes bigint;
  v_dislikes bigint;
BEGIN
  IF p_video_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'video_id and user_id are required';
  END IF;

  DELETE FROM video_reactions r
  WHERE r.video_id = p_video_id
    AND r.user_id = p_user_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted = 1 THEN
    SELECT
      count(*) FILTER (WHERE value = 'like'),
      count(*) FILTER (WHERE value = 'dislike')
    INTO v_likes, v_dislikes
    FROM video_reactions
    WHERE video_id = p_video_id;

    UPDATE videos
    SET likes_count = v_likes,
        dislikes_count = v_dislikes,
        updated_at = now()
    WHERE id = p_video_id
      AND status <> 'deleted';

    RETURN true;
  END IF;

  RETURN false;
END $$;


CREATE OR REPLACE FUNCTION video_update_comment(
  p_comment_id uuid,
  p_user_id uuid,
  p_text text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated int;
BEGIN
  IF p_comment_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'comment_id and user_id are required';
  END IF;

  IF p_text IS NULL OR length(btrim(p_text)) = 0 THEN
    RAISE EXCEPTION 'Comment text must be non-empty';
  END IF;

  UPDATE video_comments c
  SET text = p_text,
      updated_at = now()
  WHERE c.id = p_comment_id
    AND c.user_id = p_user_id
    AND c.is_deleted = false;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END $$;

COMMIT;
