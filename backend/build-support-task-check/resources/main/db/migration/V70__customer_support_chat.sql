CREATE TABLE customer_support_messages (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES users(id),
 sender VARCHAR(16) NOT NULL CHECK (sender IN ('USER', 'STAFF')),
 content VARCHAR(4000) NOT NULL,
 image_data TEXT,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX customer_support_messages_user_time ON customer_support_messages(user_id, created_at);
CREATE TABLE customer_support_message_reads (
 message_id UUID NOT NULL REFERENCES customer_support_messages(id),
 admin_id UUID NOT NULL REFERENCES users(id),
 PRIMARY KEY(message_id, admin_id)
);
