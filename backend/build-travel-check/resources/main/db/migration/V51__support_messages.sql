CREATE TABLE support_messages (
 id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id),
 sender VARCHAR(16) NOT NULL, content VARCHAR(4000) NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX support_messages_user_time ON support_messages(user_id, created_at);
