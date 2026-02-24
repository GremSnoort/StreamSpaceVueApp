-- 41_folder_video_items.sql
BEGIN;

CREATE TABLE IF NOT EXISTS folder_video_items (
  folder_id     uuid NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
  video_id      uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,

  added_by      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- кто добавил (владелец папки)
  added_at      timestamptz NOT NULL DEFAULT now(),
  order_index   integer, -- опционально для ручной сортировки

  PRIMARY KEY (folder_id, video_id)
);

CREATE INDEX IF NOT EXISTS idx_folder_video_items_video ON folder_video_items(video_id, added_at DESC);
CREATE INDEX IF NOT EXISTS idx_folder_video_items_folder_added ON folder_video_items(folder_id, added_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_folder_items_order
  ON folder_video_items(folder_id, order_index)
  WHERE order_index IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_folder_video_items_folder_order
  ON folder_video_items(folder_id, order_index NULLS LAST);

COMMIT;
