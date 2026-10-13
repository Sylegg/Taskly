CREATE TABLE partner_wallets (
 user_id UUID PRIMARY KEY REFERENCES users(id),
 balance BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0)
);
CREATE TABLE partner_wallet_transactions (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id),
 type VARCHAR(20) NOT NULL CHECK (type IN ('DEPOSIT','WITHDRAWAL')),
 amount BIGINT NOT NULL CHECK (amount > 0),
 status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING','APPROVED','PAID','COMPLETED','REJECTED')),
 bank_name VARCHAR(100), account_name VARCHAR(150), account_number VARCHAR(34),
 reference_code VARCHAR(150), note VARCHAR(500),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 completed_at TIMESTAMP WITH TIME ZONE,
 updated_by UUID REFERENCES users(id)
);
CREATE INDEX partner_wallet_transactions_owner ON partner_wallet_transactions(user_id,created_at);
