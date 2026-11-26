UPDATE tasks
SET original_scheduled_end_at = COALESCE(original_scheduled_start_at, scheduled_at)
    + estimated_duration_minutes * INTERVAL '1' MINUTE
WHERE original_scheduled_end_at IS NULL
   OR original_scheduled_end_at <= COALESCE(original_scheduled_start_at, scheduled_at);

UPDATE tasks
SET expected_end_at = COALESCE(approved_start_at, scheduled_at)
    + estimated_duration_minutes * INTERVAL '1' MINUTE
WHERE expected_end_at IS NULL
   OR expected_end_at <= COALESCE(approved_start_at, scheduled_at)
   OR (approved_start_at IS NOT NULL AND expected_end_at = scheduled_at);
