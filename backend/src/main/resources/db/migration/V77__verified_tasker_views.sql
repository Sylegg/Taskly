ALTER TABLE task_booking_payments ADD COLUMN tasker_viewed_by UUID REFERENCES users(id);
-- Legacy timestamps have no viewer identity and cannot establish a verified view.
UPDATE task_booking_payments SET tasker_viewed_at=NULL WHERE tasker_viewed_by IS NULL;
