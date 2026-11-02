CREATE TABLE customer_pending_bookings (
 id VARCHAR(64) PRIMARY KEY,
 customer_id UUID NOT NULL REFERENCES users(id),
 payload TEXT NOT NULL,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO customer_pending_bookings(id,customer_id,payload,updated_at)
 SELECT CAST(customer_id AS VARCHAR(64)),customer_id,payload,updated_at FROM customer_booking_drafts;
