CREATE TABLE customer_booking_drafts (
    customer_id UUID PRIMARY KEY REFERENCES users(id),
    payload TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
