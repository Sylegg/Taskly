CREATE TABLE task_booking_payments (
 task_id UUID PRIMARY KEY REFERENCES tasks(id),
 quote_id UUID NOT NULL UNIQUE REFERENCES customer_price_quotes(id),
 method VARCHAR(12) NOT NULL CHECK(method IN ('CASH','BANK')),
 status VARCHAR(24) NOT NULL CHECK(status IN ('AWAITING_CASH','PAID','REFUNDED')),
 amount BIGINT NOT NULL CHECK(amount>0),
 draft_payload TEXT NOT NULL,
 posted_at TIMESTAMP WITH TIME ZONE NOT NULL,
 match_deadline TIMESTAMP WITH TIME ZONE NOT NULL,
 cancel_after TIMESTAMP WITH TIME ZONE NOT NULL,
 refunded_at TIMESTAMP WITH TIME ZONE
);
CREATE TABLE task_booking_services (
 task_id UUID NOT NULL REFERENCES tasks(id),
 service_id UUID NOT NULL REFERENCES services(id),
 PRIMARY KEY(task_id,service_id)
);
CREATE TABLE customer_refund_credits (
 task_id UUID PRIMARY KEY REFERENCES tasks(id),
 customer_id UUID NOT NULL REFERENCES users(id),
 amount BIGINT NOT NULL CHECK(amount>0),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE customer_booking_notifications (
 id UUID PRIMARY KEY,
 customer_id UUID NOT NULL REFERENCES users(id),
 task_id UUID NOT NULL REFERENCES tasks(id),
 title VARCHAR(1000) NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 read_at TIMESTAMP WITH TIME ZONE
);
