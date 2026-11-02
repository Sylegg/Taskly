CREATE TABLE customer_refund_withdrawals (
 id UUID PRIMARY KEY, customer_id UUID NOT NULL REFERENCES users(id), amount BIGINT NOT NULL CHECK(amount>0),
 bank_name VARCHAR(100) NOT NULL, account_name VARCHAR(150) NOT NULL, account_number VARCHAR(34) NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','PAID','REJECTED')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX customer_refund_withdrawals_owner ON customer_refund_withdrawals(customer_id);
