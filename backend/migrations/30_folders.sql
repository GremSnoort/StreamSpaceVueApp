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
  CONSTRAINT chk_folder_name_nonempty CHECK (length(btrim(name)) > 0),
  CONSTRAINT chk_folder_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);

CREATE INDEX IF NOT EXISTS idx_folders_owner_type ON folders(owner_id, tree_type);
CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id);
CREATE INDEX IF NOT EXISTS idx_folders_owner_type_parent
  ON folders(owner_id, tree_type, parent_id);

-- parent должен быть того же owner_id и tree_type
CREATE OR REPLACE FUNCTION folders_validate_parent_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent_owner_id uuid;
  v_parent_tree_type folder_tree_type;
BEGIN
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT f.owner_id, f.tree_type
  INTO v_parent_owner_id, v_parent_tree_type
  FROM folders f
  WHERE f.id = NEW.parent_id;

  IF v_parent_owner_id IS NULL THEN
    RAISE EXCEPTION 'Parent folder does not exist';
  END IF;

  IF v_parent_owner_id <> NEW.owner_id OR v_parent_tree_type <> NEW.tree_type THEN
    RAISE EXCEPTION 'Invalid parent folder (owner/tree mismatch)';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_folders_validate_parent_integrity ON folders;
CREATE TRIGGER trg_folders_validate_parent_integrity
BEFORE INSERT OR UPDATE OF owner_id, tree_type, parent_id ON folders
FOR EACH ROW
EXECUTE FUNCTION folders_validate_parent_integrity();

COMMIT;
