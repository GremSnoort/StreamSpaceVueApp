BEGIN;

-- =========================================================
-- Additional read helpers
-- =========================================================

-- Профиль пользователя + counters + флаг подписки текущего viewer
CREATE OR REPLACE FUNCTION user_get_profile(
  p_viewer_id uuid,
  p_user_id uuid
)
RETURNS TABLE (
  user_id uuid,
  username citext,
  display_name text,
  avatar_url text,
  bio text,
  created_at timestamptz,
  followers_count bigint,
  following_count bigint,
  public_videos_count bigint,
  is_following boolean,
  is_me boolean
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.bio,
    u.created_at,
    (SELECT count(*)::bigint FROM user_follows f WHERE f.following_id = u.id) AS followers_count,
    (SELECT count(*)::bigint FROM user_follows f WHERE f.follower_id = u.id) AS following_count,
    (
      SELECT count(*)::bigint
      FROM videos v
      WHERE v.owner_id = u.id
        AND v.status = 'ready'
        AND v.visibility = 'public'
        AND v.published_at IS NOT NULL
    ) AS public_videos_count,
    (
      p_viewer_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM user_follows f
        WHERE f.follower_id = p_viewer_id
          AND f.following_id = u.id
      )
    ) AS is_following,
    (p_viewer_id IS NOT NULL AND p_viewer_id = u.id) AS is_me
  FROM users u
  WHERE u.id = p_user_id
    AND u.is_active = true;
$$;


-- One-shot дерево папок (flat list с depth/path), чтобы не делать N вызовов list_children
CREATE OR REPLACE FUNCTION folder_list_tree(
  p_owner_id uuid,
  p_tree_type folder_tree_type
)
RETURNS TABLE (
  id uuid,
  parent_id uuid,
  name text,
  depth integer,
  path uuid[],
  created_at timestamptz,
  updated_at timestamptz,
  videos_count bigint,
  children_count bigint
)
LANGUAGE sql
STABLE
AS $$
  WITH RECURSIVE t AS (
    SELECT
      f.id,
      f.parent_id,
      f.name,
      0::integer AS depth,
      ARRAY[f.id]::uuid[] AS path,
      f.created_at,
      f.updated_at
    FROM folders f
    WHERE f.owner_id = p_owner_id
      AND f.tree_type = p_tree_type
      AND f.parent_id IS NULL

    UNION ALL

    SELECT
      c.id,
      c.parent_id,
      c.name,
      t.depth + 1,
      t.path || c.id,
      c.created_at,
      c.updated_at
    FROM folders c
    JOIN t ON c.parent_id = t.id
    WHERE c.owner_id = p_owner_id
      AND c.tree_type = p_tree_type
  )
  SELECT
    t.id,
    t.parent_id,
    t.name,
    t.depth,
    t.path,
    t.created_at,
    t.updated_at,
    (SELECT count(*)::bigint FROM folder_video_items fvi WHERE fvi.folder_id = t.id) AS videos_count,
    (SELECT count(*)::bigint FROM folders f2 WHERE f2.parent_id = t.id) AS children_count
  FROM t
  ORDER BY t.path;
$$;


-- Детали одной покупки текущего пользователя
CREATE OR REPLACE FUNCTION purchase_get(
  p_buyer_id uuid,
  p_purchase_id uuid
)
RETURNS TABLE (
  purchase_id uuid,
  buyer_id uuid,
  video_id uuid,
  amount_cents integer,
  currency char(3),
  status purchase_status,
  provider text,
  provider_payment_id text,
  created_at timestamptz,
  updated_at timestamptz,
  video_owner_id uuid,
  video_title text,
  video_poster_key text,
  video_visibility video_visibility,
  can_download boolean
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id,
    p.buyer_id,
    p.video_id,
    p.amount_cents,
    p.currency,
    p.status,
    p.provider,
    p.provider_payment_id,
    p.created_at,
    p.updated_at,
    v.owner_id,
    v.title,
    v.poster_key,
    v.visibility,
    can_download_video(p.buyer_id, p.video_id) AS can_download
  FROM download_purchases p
  JOIN videos v ON v.id = p.video_id
  WHERE p.id = p_purchase_id
    AND p.buyer_id = p_buyer_id;
$$;


-- Список покупок пользователя для UI
CREATE OR REPLACE FUNCTION purchase_list_my(
  p_buyer_id uuid,
  p_status purchase_status DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  purchase_id uuid,
  video_id uuid,
  amount_cents integer,
  currency char(3),
  status purchase_status,
  provider text,
  provider_payment_id text,
  created_at timestamptz,
  updated_at timestamptz,
  video_owner_id uuid,
  video_title text,
  video_poster_key text,
  video_visibility video_visibility,
  can_download boolean
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id,
    p.video_id,
    p.amount_cents,
    p.currency,
    p.status,
    p.provider,
    p.provider_payment_id,
    p.created_at,
    p.updated_at,
    v.owner_id,
    v.title,
    v.poster_key,
    v.visibility,
    can_download_video(p.buyer_id, p.video_id) AS can_download
  FROM download_purchases p
  JOIN videos v ON v.id = p.video_id
  WHERE p.buyer_id = p_buyer_id
    AND (p_status IS NULL OR p.status = p_status)
  ORDER BY p.created_at DESC, p.id DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100)
  OFFSET GREATEST(p_offset, 0);
$$;

COMMIT;
