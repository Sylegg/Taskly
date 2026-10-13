ALTER TABLE task_arrival_reports ALTER COLUMN tasker_id DROP NOT NULL;
ALTER TABLE task_arrival_reports ADD COLUMN report_type VARCHAR(32) NOT NULL DEFAULT 'LATE_ARRIVAL';
ALTER TABLE task_arrival_reports DROP CONSTRAINT task_arrival_reports_pkey;
ALTER TABLE task_arrival_reports ADD PRIMARY KEY(task_id, report_type);
ALTER TABLE task_arrival_reports ADD CHECK (report_type IN ('LATE_ARRIVAL','NO_TASKER'));
