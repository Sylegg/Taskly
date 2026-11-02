ALTER TABLE service_pricing_rules ADD COLUMN platform_fee_percent NUMERIC(5,2) CHECK (platform_fee_percent >= 0 AND platform_fee_percent <= 100);
UPDATE service_pricing_rules SET platform_fee_percent=10, platform_fee_amount=0, version=version+1, updated_at=CURRENT_TIMESTAMP;
