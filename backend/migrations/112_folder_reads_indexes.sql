-- 112_folder_reads_indexes.sql
BEGIN;

-- Списки папок: owner/tree/parent + пагинация по created_at,id
CREATE INDEX IF NOT EXISTS idx_folders_owner_tree_parent_created_id
  ON folders(owner_id, tree_type, parent_id, created_at DESC, id DESC);

-- Быстрый favorites root lookup по имени (если используем favorites_list_videos)
CREATE INDEX IF NOT EXISTS idx_folders_owner_tree_parent_name
  ON folders(owner_id, tree_type, parent_id, name);

-- Листинг видео в папке: folder_id + (order_index, added_at, video_id)
CREATE INDEX IF NOT EXISTS idx_folder_items_folder_order_added_video
  ON folder_video_items(folder_id, order_index NULLS LAST, added_at DESC, video_id DESC);

COMMIT;
