ALTER TABLE support_messages ADD COLUMN task_id UUID REFERENCES tasks(id);
