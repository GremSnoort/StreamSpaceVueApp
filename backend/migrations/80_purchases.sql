-- 80_purchases.sql
BEGIN;

CREATE TABLE IF NOT EXISTS download_purchases (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id              uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  video_id              uuid NOT NULL REFERENCES videos(id) ON DELETE CASCADE,

  amount_cents          integer NOT NULL CHECK (amount_cents >= 0),
  currency              char(3) NOT NULL, -- 'EUR', 'USD', ...

  status                purchase_status NOT NULL DEFAULT 'pending',

  provider              text, -- stripe, paypal, ...
  provider_payment_id   text,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  -- не допускаем повторный "paid" на то же видео тем же пользователем (одна покупка = доступ)
  -- но чтобы не ломать историю попыток, уникальность делаем частичной индексом ниже.
  CONSTRAINT chk_currency_upper CHECK (currency = upper(currency))
);

-- Уникальность только для paid покупок (PostgreSQL partial unique index)
CREATE UNIQUE INDEX IF NOT EXISTS uq_paid_download_purchase
  ON download_purchases(buyer_id, video_id)
  WHERE status = 'paid';

CREATE INDEX IF NOT EXISTS idx_download_purchases_buyer_created
  ON download_purchases(buyer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_download_purchases_video_created
  ON download_purchases(video_id, created_at DESC);

COMMIT;
