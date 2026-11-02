ALTER TABLE customer_support_messages ADD COLUMN task_id UUID REFERENCES tasks(id);
CREATE TABLE task_arrival_reports (
 task_id UUID REFERENCES tasks(id),
 customer_id UUID NOT NULL REFERENCES users(id),
 tasker_id UUID NOT NULL REFERENCES users(id),
 message_id UUID NOT NULL REFERENCES customer_support_messages(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT task_arrival_reports_pkey PRIMARY KEY (task_id)
);
