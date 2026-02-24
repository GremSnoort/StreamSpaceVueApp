-- 130_purchases_functions.sql
BEGIN;

-- Создать покупку (pending)
CREATE OR REPLACE FUNCTION purchase_create(
  p_buyer_id uuid,
  p_video_id uuid,
  p_amount_cents integer,
  p_currency char(3),
  p_provider text,
  p_provider_payment_id text
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_id uuid;
  v_video_owner_id uuid;
BEGIN
  IF p_buyer_id IS NULL THEN
    RAISE EXCEPTION 'buyer_id is required';
  END IF;

  IF p_video_id IS NULL THEN
    RAISE EXCEPTION 'video_id is required';
  END IF;

  IF p_amount_cents IS NULL OR p_amount_cents < 0 THEN
    RAISE EXCEPTION 'amount_cents must be >= 0';
  END IF;

  IF p_currency IS NULL OR length(btrim(p_currency::text)) <> 3 THEN
    RAISE EXCEPTION 'currency must be a 3-letter code';
  END IF;

  SELECT v.owner_id
  INTO v_video_owner_id
  FROM videos v
  WHERE v.id = p_video_id
    AND v.status <> 'deleted';

  IF v_video_owner_id IS NULL THEN
    RAISE EXCEPTION 'Video not found (or deleted)';
  END IF;

  IF v_video_owner_id = p_buyer_id THEN
    RAISE EXCEPTION 'Cannot purchase your own video';
  END IF;

  IF NOT can_view_video(p_buyer_id, p_video_id) THEN
    RAISE EXCEPTION 'No access to video for purchase';
  END IF;

  INSERT INTO download_purchases(buyer_id, video_id, amount_cents, currency, status, provider, provider_payment_id)
  VALUES (p_buyer_id, p_video_id, p_amount_cents, upper(p_currency), 'pending', p_provider, p_provider_payment_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

-- Обновить статус покупки
CREATE OR REPLACE FUNCTION purchase_set_status(
  p_purchase_id uuid,
  p_status purchase_status
)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE download_purchases
  SET status = p_status,
      updated_at = now()
  WHERE id = p_purchase_id;
$$;

-- Эталонный вариант: конкурентно-безопасная выдача одноразового download token.
-- Предпосылки:
-- 1) В таблице video_download_tokens есть revoked_at (nullable)
-- 2) Есть partial unique index:
--    uq_active_download_token_per_purchase
--      ON video_download_tokens(purchase_id)
--      WHERE purchase_id IS NOT NULL AND used_at IS NULL AND revoked_at IS NULL;

CREATE OR REPLACE FUNCTION download_token_issue(
  p_user_id uuid,
  p_video_id uuid,
  p_purchase_id uuid DEFAULT NULL,
  p_ttl interval DEFAULT interval '15 minutes'
)
RETURNS TABLE (
  token_id uuid,
  token text,
  expires_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_ok boolean;
  v_is_owner boolean;
  v_token text;
  v_hash text;
  v_expires timestamptz;
  v_try int;
  v_constraint text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User must be provided';
  END IF;

  -- базовое право на скачивание (owner или paid purchase)
  SELECT can_download_video(p_user_id, p_video_id) INTO v_ok;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'No download rights for this video';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM videos v
    WHERE v.id = p_video_id AND v.owner_id = p_user_id
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    -- покупатель: purchase_id обязателен и должен быть paid/своим/этого видео
    IF p_purchase_id IS NULL THEN
      RAISE EXCEPTION 'purchase_id is required for non-owner download token';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM download_purchases p
      WHERE p.id = p_purchase_id
        AND p.buyer_id = p_user_id
        AND p.video_id = p_video_id
        AND p.status = 'paid'
    ) INTO v_ok;

    IF NOT v_ok THEN
      RAISE EXCEPTION 'Invalid purchase for token issuance';
    END IF;

    -- снимаем "залипшие" просроченные токены, чтобы они не блокировали новый
    UPDATE video_download_tokens
    SET revoked_at = now()
    WHERE purchase_id = p_purchase_id
      AND used_at IS NULL
      AND revoked_at IS NULL
      AND expires_at <= now();

  ELSE
    -- owner: purchase_id не обязателен; если передали — проверим соответствие видео
    IF p_purchase_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM download_purchases p
        WHERE p.id = p_purchase_id
          AND p.video_id = p_video_id
      ) INTO v_ok;

      IF NOT v_ok THEN
        RAISE EXCEPTION 'purchase_id does not match video';
      END IF;
    END IF;
  END IF;

  v_expires := now() + p_ttl;

  -- 2-3 попытки на случай коллизии token_hash (крайне маловероятно) или гонок
  FOR v_try IN 1..3 LOOP
    v_token := encode(gen_random_bytes(32), 'hex');
    v_hash  := auth_token_hash(v_token);

    BEGIN
      INSERT INTO video_download_tokens(video_id, owner_user_id, purchase_id, token_hash, expires_at)
      VALUES (p_video_id, p_user_id, p_purchase_id, v_hash, v_expires)
      RETURNING id INTO token_id;

      token := v_token;
      expires_at := v_expires;
      RETURN NEXT;
      RETURN;

    EXCEPTION
      WHEN unique_violation THEN
        -- различаем, по какому unique упали
        GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;

        IF v_constraint = 'uq_active_download_token_per_purchase' THEN
          -- значит в транзакции уже есть активный токен на purchase_id (или гонка)
          IF NOT v_is_owner THEN
            RAISE EXCEPTION 'Active download token already exists for this purchase';
          END IF;

          -- для owner purchase_id обычно NULL, но если owner передал purchase_id и
          -- хочет именно "purchase-scoped" токен — логично тоже отказать:
          RAISE EXCEPTION 'Active download token already exists for this purchase';

        ELSIF v_constraint = 'video_download_tokens_token_hash_key' THEN
          -- коллизия token_hash: просто попробуем ещё раз
          CONTINUE;

        ELSE
          -- другой unique (на всякий)
          RAISE;
        END IF;
    END;
  END LOOP;

  -- если исчерпали попытки
  RAISE EXCEPTION 'Failed to issue download token (please retry)';
END $$;

CREATE OR REPLACE FUNCTION download_token_consume(p_token text)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  v_hash text := auth_token_hash(p_token);
  v_video_id uuid;
BEGIN
  UPDATE video_download_tokens
  SET used_at = now()
  WHERE token_hash = v_hash
    AND expires_at > now()
    AND used_at IS NULL
    AND revoked_at IS NULL
  RETURNING video_id INTO v_video_id;

  -- если UPDATE не затронул строк — вернём NULL
  RETURN v_video_id;
END $$;

COMMIT;
