-- 30_folders.sql
BEGIN;

CREATE TABLE IF NOT EXISTS folders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tree_type   folder_tree_type NOT NULL, -- library | favorites

  parent_id   uuid NULL REFERENCES folders(id) ON DELETE CASCADE,
  name        text NOT NULL,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  -- Один владелец, один тип дерева, один parent, одно имя — уникально
  CONSTRAINT uq_folders_owner_type_parent_name UNIQUE (owner_id, tree_type, parent_id, name),
  -- parent должен быть того же owner_id и tree_type — это нельзя выразить CHECK без функций,
  -- поэтому гарантировать будем в приложении (позже можно триггером).
  CONSTRAINT chk_folder_name_nonempty CHECK (length(btrim(name)) > 0),
  CONSTRAINT chk_folder_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);

CREATE INDEX IF NOT EXISTS idx_folders_owner_type ON folders(owner_id, tree_type);
CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id);
CREATE INDEX IF NOT EXISTS idx_folders_owner_type_parent
  ON folders(owner_id, tree_type, parent_id);

COMMIT;
