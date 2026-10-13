CREATE TABLE partner_message_templates (
 id UUID PRIMARY KEY,event_key VARCHAR(80) NOT NULL UNIQUE,title VARCHAR(200) NOT NULL,
 body VARCHAR(2000) NOT NULL,active BOOLEAN NOT NULL,version BIGINT NOT NULL DEFAULT 0
);
ALTER TABLE partner_notification_outbox ADD COLUMN last_attempt_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE partner_notification_outbox ADD COLUMN last_error VARCHAR(500);
CREATE INDEX idx_partner_outbox_status ON partner_notification_outbox(status,created_at);
