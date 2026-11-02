ALTER TABLE task_messages ADD COLUMN sender_portal VARCHAR(8);
ALTER TABLE task_messages ADD CONSTRAINT task_message_sender_portal_check CHECK (sender_portal IN ('CUSTOMER', 'PARTNER'));
-- Infer historical sender roles only when the participants are distinct.
UPDATE task_messages SET sender_portal = CASE WHEN sender_id = (SELECT customer_id FROM tasks WHERE tasks.id = task_messages.task_id) THEN 'CUSTOMER' ELSE 'PARTNER' END
WHERE task_id IN (SELECT id FROM tasks WHERE customer_id <> tasker_id);
