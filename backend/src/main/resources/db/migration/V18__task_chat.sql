ALTER TABLE tasks ADD COLUMN tasker_id UUID REFERENCES users(id);
CREATE TABLE task_messages(id UUID PRIMARY KEY, task_id UUID NOT NULL REFERENCES tasks(id), sender_id UUID NOT NULL REFERENCES users(id), content VARCHAR(4000) NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE INDEX idx_task_messages_timeline ON task_messages(task_id,created_at);
