CREATE TABLE support_message_reads (message_id UUID NOT NULL REFERENCES support_messages(id), admin_id UUID NOT NULL REFERENCES users(id), PRIMARY KEY(message_id,admin_id));
