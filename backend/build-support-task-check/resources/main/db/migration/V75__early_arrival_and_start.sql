-- Migration V75: Support for early arrival, check-in, early start request and approval, and independent timestamps

-- 1. Extend tasks table with independent lifecycle timestamps and tracking
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS original_scheduled_start_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS original_scheduled_end_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS approved_start_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS expected_end_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS actual_started_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS early_start_request_id UUID;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS booking_timezone VARCHAR(64) DEFAULT 'Asia/Ho_Chi_Minh';

-- Backfill original scheduled times from scheduled_at
UPDATE tasks
SET original_scheduled_start_at = scheduled_at
WHERE original_scheduled_start_at IS NULL AND scheduled_at IS NOT NULL;

UPDATE tasks
SET original_scheduled_end_at = scheduled_at
WHERE original_scheduled_end_at IS NULL AND scheduled_at IS NOT NULL;

UPDATE tasks
SET expected_end_at = scheduled_at
WHERE expected_end_at IS NULL AND scheduled_at IS NOT NULL;

-- 2. Create early_start_requests table
CREATE TABLE IF NOT EXISTS early_start_requests (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES users(id),
    requested_start_at TIMESTAMP WITH TIME ZONE NOT NULL,
    proposed_end_at TIMESTAMP WITH TIME ZONE NOT NULL,
    reason VARCHAR(500),
    status VARCHAR(32) NOT NULL, -- PENDING, APPROVED, REJECTED, CANCELLED, EXPIRED, APPLIED
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP WITH TIME ZONE,
    responded_by UUID REFERENCES users(id),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_early_start_requests_task ON early_start_requests(task_id, status);
CREATE INDEX IF NOT EXISTS idx_early_start_requests_partner ON early_start_requests(partner_id, requested_start_at);

-- 3. Insert default system settings for early check-in and early start policy
INSERT INTO system_settings (setting_key, setting_value, description)
VALUES
    ('partner.early_checkin_window_minutes', '15', 'Khoảng thời gian cho phép check-in sớm trước giờ bắt đầu (phút)'),
    ('partner.max_early_start_minutes', '60', 'Số phút tối đa Partner được đề nghị bắt đầu sớm (phút)'),
    ('partner.early_start_expiry_minutes', '15', 'Thời hạn tự động hết hạn của đề nghị bắt đầu sớm nếu khách không trả lời (phút)');
