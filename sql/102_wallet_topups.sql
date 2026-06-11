-- Wallet top-up orders (Razorpay) — separate from booking payments.

CREATE TABLE IF NOT EXISTS wallet_topups (
  topup_id bigserial PRIMARY KEY,
  customerid bigint NOT NULL,
  wallet_id bigint NOT NULL,
  amount numeric(10, 2) NOT NULL,
  status character varying(50) NOT NULL DEFAULT 'PENDING',
  razorpay_order_id character varying(255),
  razorpay_payment_id character varying(255),
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS wallet_topups_customerid_idx
  ON wallet_topups (customerid);

CREATE UNIQUE INDEX IF NOT EXISTS wallet_topups_razorpay_order_id_idx
  ON wallet_topups (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;
