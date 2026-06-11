-- Wallet split at checkout: wallet_amount is applied on payment success (or immediately for wallet-only).

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS wallet_amount numeric(10, 2) NOT NULL DEFAULT 0;

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS wallet_deducted boolean NOT NULL DEFAULT false;
