-- 140_transcoding_functions.sql
BEGIN;

-- Поставить задачу в очередь (если активной нет — индекс uq_video_one_active_transcode_job это гарантирует)
CREATE OR REPLACE FUNCTION transcode_enqueue(p_video_id uuid, p_priority integer DEFAULT 100)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO video_transcode_jobs(video_id, status, priority, queued_at)
  VALUES (p_video_id, 'queued', p_priority, now())
  RETURNING id INTO v_id;

  -- видео переходит в processing
  UPDATE videos
  SET status = 'processing',
      updated_at = now()
  WHERE id = p_video_id;

  RETURN v_id;
END $$;

-- Взять следующую задачу воркером (атомарно, безопасно)
CREATE OR REPLACE FUNCTION transcode_claim_next(p_worker_id text)
RETURNS TABLE (
  job_id uuid,
  video_id uuid,
  attempt integer,
  max_attempts integer,
  input_storage_key text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH cte AS (
    SELECT j.id
    FROM video_transcode_jobs j
    WHERE j.status = 'queued'
    ORDER BY j.priority ASC, j.queued_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  )
  UPDATE video_transcode_jobs j
  SET status = 'running',
      worker_id = p_worker_id,
      started_at = now(),
      attempt = j.attempt + 1,
      updated_at = now()
  FROM cte
  WHERE j.id = cte.id
  RETURNING j.id, j.video_id, j.attempt, j.max_attempts, j.input_storage_key;
END $$;

-- Завершить задачу (успех/ошибка) + выставить статус видео
CREATE OR REPLACE FUNCTION transcode_finish(
  p_job_id uuid,
  p_status transcode_job_status,
  p_error_message text DEFAULT NULL,
  p_hls_master_key text DEFAULT NULL,
  p_poster_key text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_video_id uuid;
BEGIN
  SELECT video_id INTO v_video_id
  FROM video_transcode_jobs
  WHERE id = p_job_id;

  UPDATE video_transcode_jobs
  SET status = p_status,
      finished_at = now(),
      error_message = p_error_message,
      updated_at = now()
  WHERE id = p_job_id;

  IF p_status = 'succeeded' THEN
    UPDATE videos
    SET status = 'ready',
        hls_master_key = COALESCE(p_hls_master_key, hls_master_key),
        poster_key = COALESCE(p_poster_key, poster_key),
        updated_at = now()
    WHERE id = v_video_id;
  ELSIF p_status IN ('failed','canceled') THEN
    UPDATE videos
    SET status = 'failed',
        updated_at = now()
    WHERE id = v_video_id;
  END IF;
END $$;

COMMIT;
