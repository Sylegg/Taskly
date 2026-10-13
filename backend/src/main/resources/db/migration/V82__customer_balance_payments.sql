ALTER TABLE task_booking_payments ADD COLUMN balance_amount BIGINT NOT NULL DEFAULT 0 CHECK(balance_amount >= 0 AND balance_amount <= amount);
