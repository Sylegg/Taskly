CREATE TABLE partner_task_settlements (
 task_id UUID PRIMARY KEY REFERENCES tasks(id),
 partner_id UUID NOT NULL REFERENCES users(id),
 method VARCHAR(20) NOT NULL,
 wallet_delta BIGINT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
