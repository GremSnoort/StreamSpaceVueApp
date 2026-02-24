BEGIN;

CREATE OR REPLACE FUNCTION download_tokens_cleanup_expired()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_cnt integer;
BEGIN
  UPDATE video_download_tokens
  SET revoked_at = now()
  WHERE revoked_at IS NULL
    AND used_at IS NULL
    AND expires_at <= now();

  GET DIAGNOSTICS v_cnt = ROW_COUNT;
  RETURN v_cnt;
END $$;

COMMIT;
