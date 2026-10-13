CREATE TABLE wallet_finance_settings (
 id INTEGER PRIMARY KEY CHECK (id=1),
 min_deposit BIGINT NOT NULL DEFAULT 50000,
 max_deposit BIGINT NOT NULL DEFAULT 50000000,
 min_withdraw BIGINT NOT NULL DEFAULT 100000,
 max_withdraw_daily BIGINT NOT NULL DEFAULT 20000000,
 withdraw_fee_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
 bank_name VARCHAR(150) NOT NULL DEFAULT 'Vietcombank',
 bank_account VARCHAR(34) NOT NULL DEFAULT '0988889999',
 account_owner VARCHAR(150) NOT NULL DEFAULT 'CONG TY CO PHAN TASKLY VIET NAM',
 qr_prefix VARCHAR(80) NOT NULL DEFAULT 'TASKLY NAP',
 updated_by UUID REFERENCES users(id), updated_at TIMESTAMP WITH TIME ZONE
);
INSERT INTO wallet_finance_settings(id) VALUES(1);
ALTER TABLE partner_wallet_transactions ADD COLUMN fee BIGINT NOT NULL DEFAULT 0;
ALTER TABLE partner_wallet_transactions ADD COLUMN method VARCHAR(150) NOT NULL DEFAULT 'Nạp ví';
ALTER TABLE partner_wallet_transactions ADD COLUMN user_role VARCHAR(20) NOT NULL DEFAULT 'PARTNER';
