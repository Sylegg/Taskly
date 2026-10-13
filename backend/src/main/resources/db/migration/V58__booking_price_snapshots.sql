CREATE TABLE booking_price_snapshots (
 customer_id UUID NOT NULL REFERENCES users(id),
 booking_id UUID NOT NULL,
 service_id UUID NOT NULL REFERENCES services(id),
 rule_payload TEXT NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(customer_id,booking_id,service_id)
);
