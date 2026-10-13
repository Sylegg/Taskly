-- Fee is deducted from partner earnings, never added to the customer price.
ALTER TABLE tasks ADD COLUMN platform_fee_snapshot BIGINT CHECK (platform_fee_snapshot >= 0 AND platform_fee_snapshot <= budget_amount);
-- Old quotes used the customer surcharge model and must be refreshed.
UPDATE customer_price_quotes SET expires_at=LEAST(expires_at,CURRENT_TIMESTAMP);
