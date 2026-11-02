-- Migration V66: Partner notification enhancements
ALTER TABLE partner_notification_outbox ADD COLUMN IF NOT EXISTS task_id UUID;
CREATE INDEX IF NOT EXISTS idx_partner_outbox_app_created ON partner_notification_outbox(application_id, created_at DESC);
