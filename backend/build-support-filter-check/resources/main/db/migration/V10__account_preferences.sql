CREATE TABLE user_payment_methods (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('CASH', 'BANK')),
    name VARCHAR(100) NOT NULL,
    detail VARCHAR(160) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, kind, name, detail)
);
CREATE INDEX payment_methods_by_user ON user_payment_methods(user_id, is_default);
CREATE TABLE user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE customer_reviews (
    task_id UUID PRIMARY KEY REFERENCES tasks(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
    comment VARCHAR(2000) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
