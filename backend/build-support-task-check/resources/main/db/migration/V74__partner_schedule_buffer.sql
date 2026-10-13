CREATE TABLE system_settings (
  setting_key VARCHAR(64) PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  description VARCHAR(500),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_settings (setting_key, setting_value, description)
VALUES
  ('partner.min_buffer_minutes', '60', 'Khoảng thời gian tối thiểu giữa 2 công việc của Partner (phút)'),
  ('partner.travel_safety_minutes', '15', 'Thời gian đệm an toàn di chuyển bổ sung (phút)');

ALTER TABLE tasks ADD COLUMN verified_actual_end_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX idx_tasks_tasker_schedule ON tasks(tasker_id, status, scheduled_at);
