-- 42_transcoding_jobs.sql
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transcode_job_status') THEN
    CREATE TYPE transcode_job_status AS ENUM ('queued', 'running', 'succeeded', 'failed', 'canceled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS video_transcode_jobs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id          uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,

  status            transcode_job_status NOT NULL DEFAULT 'queued',
  priority          integer NOT NULL DEFAULT 100,

  attempt           integer NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  max_attempts      integer NOT NULL DEFAULT 3 CHECK (max_attempts >= 1),

  queued_at         timestamptz NOT NULL DEFAULT now(),
  started_at        timestamptz NULL,
  finished_at       timestamptz NULL,

  worker_id         text,
  error_message     text,
  error_details     text,

  input_storage_key text,
  output_hls_prefix text,
  output_poster_key text,

  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- одна активная задача на видео (можем хранить историю failed/succeeded)
CREATE UNIQUE INDEX IF NOT EXISTS uq_video_one_active_transcode_job
  ON video_transcode_jobs(video_id)
  WHERE status IN ('queued', 'running');

CREATE INDEX IF NOT EXISTS idx_transcode_jobs_status_priority
  ON video_transcode_jobs(status, priority, queued_at);

CREATE INDEX IF NOT EXISTS idx_transcode_jobs_video
  ON video_transcode_jobs(video_id);

COMMIT;
