-- 100_auth_functions.sql
BEGIN;

-- Хелпер: sha256(token) -> hex
CREATE OR REPLACE FUNCTION auth_token_hash(p_token text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT encode(digest(p_token, 'sha256'), 'hex');
$$;

-- Создать сессию: генерим raw токен, в БД кладём только hash
CREATE OR REPLACE FUNCTION auth_create_session(
  p_user_id uuid,
  p_user_agent text DEFAULT NULL,
  p_ip inet DEFAULT NULL,
  p_ttl interval DEFAULT interval '30 days'
)
RETURNS TABLE (
  session_id uuid,
  session_token text,
  expires_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_token text;
  v_hash text;
  v_expires timestamptz;
BEGIN
  v_token := encode(gen_random_bytes(32), 'hex');
  v_hash := auth_token_hash(v_token);
  v_expires := now() + p_ttl;

  INSERT INTO user_sessions (user_id, session_token_hash, user_agent, ip_address, expires_at)
  VALUES (p_user_id, v_hash, p_user_agent, p_ip, v_expires)
  RETURNING id INTO session_id;

  session_token := v_token;
  expires_at := v_expires;
  RETURN NEXT;
END $$;

-- Удалить сессию по raw токену (logout)
CREATE OR REPLACE FUNCTION auth_delete_session(p_session_token text)
RETURNS boolean
LANGUAGE sql
AS $$
  WITH d AS (
    DELETE FROM user_sessions
    WHERE session_token_hash = auth_token_hash(p_session_token)
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM d);
$$;

-- Получить пользователя по raw токену + touch last_seen
CREATE OR REPLACE FUNCTION auth_get_user_by_session(p_session_token text)
RETURNS TABLE (
  user_id uuid,
  email citext,
  username citext,
  display_name text,
  avatar_url text,
  is_active boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_hash text := auth_token_hash(p_session_token);
BEGIN
  -- touch сессии, если она валидна
  UPDATE user_sessions
  SET last_seen_at = now()
  WHERE session_token_hash = v_hash
    AND expires_at > now();

  RETURN QUERY
  SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.is_active
  FROM user_sessions s
  JOIN users u ON u.id = s.user_id
  WHERE s.session_token_hash = v_hash
    AND s.expires_at > now();
END $$;

-- Очистка истёкших сессий
CREATE OR REPLACE FUNCTION auth_cleanup_expired_sessions()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_cnt integer;
BEGIN
  DELETE FROM user_sessions
  WHERE expires_at <= now();
  GET DIAGNOSTICS v_cnt = ROW_COUNT;
  RETURN v_cnt;
END $$;

COMMIT;
