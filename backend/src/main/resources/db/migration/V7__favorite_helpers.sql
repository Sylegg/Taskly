CREATE TABLE favorite_helpers (
    customer_id UUID NOT NULL REFERENCES users(id),
    helper_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, helper_id),
    CHECK (customer_id <> helper_id)
);
